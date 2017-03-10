
module Docker
  class ServiceCreator

    attr_reader :grid_service, :host_node, :service_container

    ##
    # @param [GridService] grid_service
    # @param [HostNode] host_node
    def initialize(grid_service, host_node)
      @grid_service = grid_service
      @host_node = host_node
    end

    ##
    # @param [Integer] instance_number
    # @param [String] deploy_rev
    # @param [Hash,NilClass] creds
    def create_service_instance(instance_number, deploy_rev, creds)
      service_spec = self.service_spec(instance_number, deploy_rev, creds)
      self.request_create_service(service_spec)
    end

    # @param [Integer] instance_number
    # @param [String] deploy_rev
    # @param [Hash,NilClass] creds
    # @return [Hash]
    def service_spec(instance_number, deploy_rev, creds = nil)
      spec = {
        service_id: grid_service.id.to_s,
        service_name: grid_service.name_with_stack,
        service_revision: grid_service.revision,
        updated_at: grid_service.updated_at.to_s,
        instance_number: instance_number,
        image_name: grid_service.image_name,
        image_credentials: creds,
        deploy_rev: deploy_rev,
        stateful: grid_service.stateful,
        user: grid_service.user,
        cmd: grid_service.cmd,
        entrypoint: grid_service.entrypoint,
        memory: grid_service.memory,
        memory_swap: grid_service.memory_swap,
        cpu_shares: grid_service.cpu_shares,
        privileged: grid_service.privileged,
        cap_add: grid_service.cap_add,
        cap_drop: grid_service.cap_drop,
        devices: grid_service.devices,
        ports: grid_service.ports,
        volumes_from: grid_service.volumes_from,
        net: grid_service.net,
        hostname: build_hostname(grid_service, instance_number),
        domainname: build_domainname(grid_service),
        exposed: grid_service.stack_exposed?,
        log_driver: grid_service.log_driver,
        log_opts: grid_service.log_opts,
        pid: grid_service.pid,
        wait_for_port: grid_service.deploy_opts.wait_for_port
      }
      spec[:env] = build_env(instance_number)
      spec[:secrets] = build_secrets

      labels = build_labels

      spec[:labels] = labels
      spec[:hooks] = build_hooks(instance_number)

      spec[:networks] = build_networks

      spec[:volumes] = build_volumes(instance_number)

      spec
    rescue => exc
      puts exc.message
      puts exc.backtrace.join("\n")
    end

    ##
    # @param [Hash] service_spec
    def request_create_service(service_spec)
      client.request('/service_pods/create', service_spec)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 300)
    end

    ##
    # @return [Array<String>]
    def build_env(instance_number)
      env = grid_service.env.dup || []
      env << "KONTENA_SERVICE_ID=#{grid_service.id.to_s}"
      env << "KONTENA_SERVICE_NAME=#{grid_service.name}"
      env << "KONTENA_GRID_NAME=#{grid_service.grid.try(:name)}"
      env << "KONTENA_STACK_NAME=#{grid_service.stack.try(:name)}"
      env << "KONTENA_NODE_NAME=#{host_node.name}"
      env << "KONTENA_SERVICE_INSTANCE_NUMBER=#{instance_number}"
      env
    end

    # @return [Array<Hash>]
    def build_secrets
      secrets = []
      grid = grid_service.grid
      grid_service.secrets.each do |secret|
        grid_secret = grid.grid_secrets.find_by(name: secret.secret)
        item = {name: secret.name, type: secret.type, value: nil}
        if grid_secret
          item[:value] = grid_secret.value
        end
        secrets << item
      end
      secrets
    end

    ##
    # @return [Hash]
    def build_labels
      labels = {
        'io.kontena.container.id' => service_container.id.to_s,
        'io.kontena.service.id' => grid_service.id.to_s,
        'io.kontena.service.name' => grid_service.name.to_s,
        'io.kontena.stack.name' => grid_service.stack.name.to_s,
        'io.kontena.grid.name' => grid_service.grid.try(:name)
      }
      if grid_service.linked_to_load_balancer?
        lb = grid_service.linked_to_load_balancers[0]
        internal_port = grid_service.env_hash['KONTENA_LB_INTERNAL_PORT'] || '80'
        mode = grid_service.env_hash['KONTENA_LB_MODE'] || 'http'
        labels['io.kontena.load_balancer.name'] = lb.qualified_name
        labels['io.kontena.load_balancer.internal_port'] = internal_port
        labels['io.kontena.load_balancer.mode'] = mode
      end
      if grid_service.health_check && grid_service.health_check.is_valid?
        labels['io.kontena.health_check.uri'] = grid_service.health_check.uri
        labels['io.kontena.health_check.protocol'] = grid_service.health_check.protocol
        labels['io.kontena.health_check.interval'] = grid_service.health_check.interval.to_s
        labels['io.kontena.health_check.timeout'] = grid_service.health_check.timeout.to_s
        labels['io.kontena.health_check.initial_delay'] = grid_service.health_check.initial_delay.to_s
        labels['io.kontena.health_check.port'] = grid_service.health_check.port.to_s
      end
      labels
    end

    # @return [Array<Hash>]
    def build_hooks(instance_number)
      hooks = []
      grid_service.hooks.each do |hook|
        if hook.instances.include?('*') || hook.instances.include?(instance_number.to_s)
          unless hook.done_for?(instance_number.to_s)
            hooks << {type: hook.type, cmd: hook.cmd}
            hook.push(:done => instance_number.to_s) if hook.oneshot
          end
        end
      end
      hooks
    rescue => exc
      puts exc.message
    end

    # @return [Array<Hash>]
    def build_networks
      networks = []
      grid_service.networks.each do |network|
        networks << {
          name: network.name,
          subnet: network.subnet,
          multicast: network.multicast,
          internal: network.internal
        }
      end
      networks
    end

    def build_volumes(instance_number)
      volume_specs = []
      grid_service.service_volumes.each do |sv|
        if sv.volume
          volume_name = sv.volume.name_for_service(grid_service, instance_number)
          volume_specs << {
              name: volume_name,
              path: sv.path,
              flags: sv.flags,
              driver: sv.volume.driver,
              driver_opts: sv.volume.driver_opts
          }
        else
          volume_specs << {
              bind_mount: sv.bind_mount,
              path: sv.path,
              flags: sv.flags,
          }
        end
      end

      volume_specs
    end

    # @param [GridService] grid_service
    # @param [Integer] instance_number
    # @return [String]
    def build_hostname(grid_service, instance_number)
      "#{grid_service.name}-#{instance_number}"
    end

    # @param [GridService] grid_service
    # @return [String]
    def build_domainname(grid_service)
      if grid_service.stack.name == Stack::NULL_STACK
        "#{grid_service.grid.name}.kontena.local"
      else
        "#{grid_service.stack.name}.#{grid_service.grid.name}.kontena.local"
      end
    end

    def service_container
      if @service_container.nil?
        @service_container = Container.new(
          grid: grid_service.grid,
          grid_service: grid_service,
          host_node: host_node
        )
      end
      @service_container
    end
  end
end
