require_relative 'overlay_cidr_allocator'

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
        service_name: grid_service.name,
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
        volumes: grid_service.volumes,
        volumes_from: grid_service.volumes_from,
        net: grid_service.net,
        log_driver: grid_service.log_driver,
        log_opts: grid_service.log_opts,
        pid: grid_service.pid
      }
      spec[:env] = build_env
      spec[:secrets] = build_secrets
      overlay_cidr = nil
      if grid_service.overlay_network?
        overlay_cidr = reserve_overlay_cidr(instance_number)
      end
      labels = build_labels
      if overlay_cidr
        labels['io.kontena.container.overlay_cidr'] = overlay_cidr.to_s
      end
      spec[:labels] = labels
      spec[:hooks] = build_hooks(instance_number)

      spec
    rescue => exc
      puts exc.message
      puts exc.backtrace.join("\n")
    end

    # @param [Integer] instance_number
    # @return [OverlayCidr]
    def reserve_overlay_cidr(instance_number)
      return unless grid_service.grid
      allocator = Docker::OverlayCidrAllocator.new(grid_service.grid)
      allocator.allocate_for_service_instance("#{grid_service.name}-#{instance_number}")
    end

    ##
    # @param [Hash] service_spec
    def request_create_service(service_spec)
      client.request('/service_pods/create', service_spec)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 5)
    end

    ##
    # @return [Array<String>]
    def build_env
      env = grid_service.env.dup || []
      env << "KONTENA_SERVICE_ID=#{grid_service.id.to_s}"
      env << "KONTENA_SERVICE_NAME=#{grid_service.name}"
      env << "KONTENA_GRID_NAME=#{grid_service.grid.try(:name)}"
      env << "KONTENA_NODE_NAME=#{host_node.name}"
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
        'io.kontena.grid.name' => grid_service.grid.try(:name)
      }
      if grid_service.linked_to_load_balancer?
        lb = grid_service.linked_to_load_balancers[0]
        internal_port = grid_service.env_hash['KONTENA_LB_INTERNAL_PORT'] || '80'
        mode = grid_service.env_hash['KONTENA_LB_MODE'] || 'http'
        labels['io.kontena.load_balancer.name'] = lb.name
        labels['io.kontena.load_balancer.internal_port'] = internal_port
        labels['io.kontena.load_balancer.mode'] = mode
      end
      if grid_service.health_check
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
