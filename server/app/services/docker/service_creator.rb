require_relative 'image_puller'

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
      self.ensure_service_container(instance_number)
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
        log_opts: grid_service.log_opts
      }
      spec[:env] = build_env
      overlay_cidr = nil
      if grid_service.overlay_network?
        overlay_cidr = reserve_overlay_cidr
      end
      labels = build_labels
      if overlay_cidr
        labels['io.kontena.container.overlay_cidr'] = overlay_cidr.to_s
      end
      spec[:labels] = labels

      spec
    end

    # @return [OverlayCidr]
    def reserve_overlay_cidr
      return unless grid_service.grid
      grid = grid_service.grid
      overlay_cidr = nil
      grid.available_overlay_ips.shuffle.each do |ip|
        next if ip[-2..-1] == '.0' || ip[-4..-1] == '.255'
        begin
          overlay_cidr = OverlayCidr.create!(
            grid: grid,
            ip: ip,
            subnet: grid.overlay_network_size
          )
          break
        rescue Moped::Errors::OperationFailure
        end
      end
      overlay_cidr
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
    # @return [Array]
    def build_env
      env = grid_service.env.dup || []
      env << "KONTENA_SERVICE_ID=#{grid_service.id.to_s}"
      env << "KONTENA_SERVICE_NAME=#{grid_service.name}"
      env << "KONTENA_GRID_NAME=#{grid_service.grid.try(:name)}"
      env
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
      labels
    end

    def ensure_service_container(instance_number)
      if @service_container.nil?
        @service_container = Container.create!(
          grid: grid_service.grid,
          grid_service: grid_service,
          host_node: host_node,
          name: "#{grid_service.name}-#{instance_number}"
        )
      end
    end
  end
end
