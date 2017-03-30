module Rpc
  class ServicePodSerializer

    DEFAULT_REGISTRY = 'index.docker.io'

    attr_reader :service_instance, :service

    def initialize(service_instance)
      @service_instance = service_instance
      @service = service_instance.grid_service
    end

    def to_hash
      {
        id: "#{service.id.to_s}/#{service_instance.instance_number}",
        desired_state: service_instance.desired_state,
        service_id: service.id.to_s,
        service_name: service.name_with_stack,
        service_revision: service.revision,
        updated_at: service.updated_at.to_s,
        instance_number: service_instance.instance_number,
        image_name: service.image_name,
        image_credentials: image_credentials,
        deploy_rev: service_instance.deploy_rev,
        stateful: service.stateful,
        user: service.user,
        cmd: service.cmd,
        entrypoint: service.entrypoint,
        memory: service.memory,
        memory_swap: service.memory_swap,
        cpu_shares: service.cpu_shares,
        privileged: service.privileged,
        cap_add: service.cap_add,
        cap_drop: service.cap_drop,
        devices: service.devices,
        ports: service.ports,
        volumes: build_volumes,
        volumes_from: service.volumes_from,
        net: service.net,
        hostname: build_hostname,
        domainname: build_domainname,
        exposed: service.stack_exposed?,
        log_driver: service.log_driver,
        log_opts: service.log_opts,
        pid: service.pid,
        wait_for_port: service.deploy_opts.wait_for_port,
        stop_grace_period: service.stop_grace_period,
        env: build_env,
        secrets: build_secrets,
        labels: build_labels,
        hooks: build_hooks,
        networks: build_networks
      }
    end

    def build_secrets
      secrets = []
      grid = service.grid
      service.secrets.each do |secret|
        grid_secret = grid.grid_secrets.find_by(name: secret.secret)
        item = {name: secret.name, type: secret.type, value: nil}
        if grid_secret
          item[:value] = grid_secret.value
        end
        secrets << item
      end
      secrets
    end

    def build_env
      env = service.env.dup || []
      env << "KONTENA_SERVICE_ID=#{service.id.to_s}"
      env << "KONTENA_SERVICE_NAME=#{service.name}"
      env << "KONTENA_GRID_NAME=#{service.grid.try(:name)}"
      env << "KONTENA_STACK_NAME=#{service.stack.try(:name)}"
      env << "KONTENA_NODE_NAME=#{service_instance.host_node.name}"
      env << "KONTENA_SERVICE_INSTANCE_NUMBER=#{service_instance.instance_number}"
      env
    end

    def build_labels
      labels = {
        'io.kontena.service.id' => service.id.to_s,
        'io.kontena.service.name' => service.name.to_s,
        'io.kontena.stack.name' => service.stack.name.to_s,
        'io.kontena.grid.name' => service.grid.try(:name)
      }
      if service.linked_to_load_balancer?
        lb = service.linked_to_load_balancers[0]
        internal_port = service.env_hash['KONTENA_LB_INTERNAL_PORT'] || '80'
        mode = service.env_hash['KONTENA_LB_MODE'] || 'http'
        labels['io.kontena.load_balancer.name'] = lb.qualified_name
        labels['io.kontena.load_balancer.internal_port'] = internal_port
        labels['io.kontena.load_balancer.mode'] = mode
      end
      if service.health_check && service.health_check.protocol
        labels['io.kontena.health_check.uri'] = service.health_check.uri
        labels['io.kontena.health_check.protocol'] = service.health_check.protocol
        labels['io.kontena.health_check.interval'] = service.health_check.interval.to_s
        labels['io.kontena.health_check.timeout'] = service.health_check.timeout.to_s
        labels['io.kontena.health_check.initial_delay'] = service.health_check.initial_delay.to_s
        labels['io.kontena.health_check.port'] = service.health_check.port.to_s
      end
      labels
    end

    # @return [Array<Hash>]
    def build_hooks
      hooks = []
      instance_number = service_instance.instance_number.to_s
      service.hooks.each do |hook|
        if hook.instances.include?('*') || hook.instances.include?(instance_number)
          unless hook.done_for?(instance_number)
            hooks << {type: hook.type, cmd: hook.cmd}
            hook.push(:done => instance_number) if hook.oneshot
          end
        end
      end
      hooks
    end

    # @return [Array<Hash>]
    def build_networks
      networks = []
      service.networks.each do |network|
        networks << {
          name: network.name,
          subnet: network.subnet,
          multicast: network.multicast,
          internal: network.internal
        }
      end
      networks
    end

    def build_hostname
      "#{service.name}-#{service_instance.instance_number}"
    end

    def build_domainname
      if service.stack.name == Stack::NULL_STACK
        "#{service.grid.name}.kontena.local"
      else
        "#{service.stack.name}.#{service.grid.name}.kontena.local"
      end
    end

    # @return [Hash,NilClass]
    def image_credentials
      registry = service.grid.registries.find_by(name: registry_name)
      if registry
        registry.to_creds
      end
    end

    # @return [String]
    def registry_name
      image_name = service.image_name.to_s
      return DEFAULT_REGISTRY unless image_name.include?('/')

      name = image_name.to_s.split('/')[0]
      if name.match(/(\.|:)/)
        name
      else
        DEFAULT_REGISTRY
      end
    end

    def build_volumes
      volume_specs = []
      service.service_volumes.each do |sv|
        if sv.volume
          volume_name = sv.volume.name_for_service(service, service_instance.instance_number)
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
  end
end
