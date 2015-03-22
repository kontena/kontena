module Docker
  class ContainerStarter

    attr_reader :container

    ##
    # @param [Container] container
    def initialize(container)
      @container = container
    end

    def start_container
      docker_opts = {
        'Image' => container.image
      }
      if grid_service.stateful?
        volume_container = self.ensure_volume_container(docker_opts)
        docker_opts['VolumesFrom'] = volume_container.container_id
      end
      if grid_service.volumes_from.size > 0
        i = container.name.match(/^.+-(\d+)$/)[1]
        docker_opts['VolumesFrom'] = grid_service.volumes_from.map{|v| v % [i] }
      end
      docker_opts['RestartPolicy'] = {
          'Name' => 'always',
          'MaximumRetryCount' => 10
      }
      docker_opts['PortBindings'] = port_bindings(grid_service.ports) if grid_service.ports
      client.request('/containers/start', container.container_id, docker_opts)
    end

    ##
    # @param [Hash] docker_opts
    # @return [Container]
    def ensure_volume_container(docker_opts)
      name = "#{self.container.name}-volumes"
      container = grid_service.volume_by_name(name)
      unless container
        volume_opts = {
          'Image' => docker_opts['Image'],
          'name' => name,
          'Entrypoint' => '/bin/sh',
          'Volumes' => build_volumes,
          'Cmd' => ['echo', 'Data only container'],
          'Env' => [
            "KONTENA_SERVICE=#{grid_service.id.to_s}"
          ]
        }
        resp = client.request('/containers/create', volume_opts)
        container = grid_service.containers.build(
          host_node: host_node,
          grid: grid_service.grid,
          name: name,
          image: docker_opts['Image'],
          container_type: 'volume'
        )
        container.attributes_from_docker(resp)
        container.save
      end

      container
    end

    private

    ##
    # @param [Array<Hash>] ports
    # @return [Hash]
    def port_bindings(ports)
      bindings = {}
      ports.each do |p|
        bindings["#{p['container_port']}/#{p['protocol']}"] = [{'HostPort' => p['node_port'].to_s}]
      end
      bindings
    end

    ##
    # @return [Hash]
    def build_volumes
      volumes = {}
      grid_service.volumes.each do |vol|
        volumes[vol] = {}
      end
      volumes
    end

    ##
    # @return [HostNode]
    def host_node
      self.container.host_node
    end

    ##
    # @return [GridService]
    def grid_service
      self.container.grid_service
    end

    ##
    # @return [RpcClient]
    def client
      host_node.rpc_client
    end
  end
end
