require_relative 'image_puller'
require_relative 'container_overlay_config'

module Docker
  class ContainerCreator

    attr_reader :grid_service, :host_node

    ##
    # @param [GridService] grid_service
    # @param [HostNode] host_node
    def initialize(grid_service, host_node)
      @grid_service = grid_service
      @host_node = host_node
    end

    ##
    # @return [Container]
    def create_container(name, deploy_rev)
      container = Container.create(
        grid: grid_service.grid,
        host_node: self.host_node,
        name: name,
        image: self.grid_service.image,
        deploy_rev: deploy_rev
      )
      if self.grid_service.overlay_network?
        ContainerOverlayConfig.reserve_overlay_cidr(self.grid_service, container)
      end
      docker_opts = ContainerOptsBuilder.build_opts(self.grid_service, container)

      if grid_service.stateful?
        volume_container = self.ensure_volume_container(container, docker_opts)
        docker_opts['HostConfig']['VolumesFrom'] = [volume_container.container_id]
      end

      resp = request_create_container(docker_opts)
      sync_container_with_docker_response(container, resp)
      container
    rescue => exc
      container.destroy if container
      raise exc
    end

    ##
    # @param [Hash] docker_opts
    # @return [Container]
    def request_create_container(docker_opts)
      client.request('/containers/create', docker_opts)
    end

    ##
    # @param [Container] container
    # @param [Hash] resp
    def sync_container_with_docker_response(container, resp)
      container.attributes_from_docker(resp)
      container.grid_service = self.grid_service
      container.save
    end

    ##
    # @param [Container] container
    # @param [Hash] docker_opts
    # @return [Container]
    def ensure_volume_container(container, docker_opts)
      volume_opts = ContainerOptsBuilder.build_volume_opts(
          grid_service, container.name, docker_opts['Image']
      )
      volume_container = grid_service.volume_by_name(volume_opts['name'])
      unless volume_container
        resp = request_create_container(volume_opts)
        volume_container = grid_service.containers.build(
          host_node: host_node,
          grid: grid_service.grid,
          name: volume_opts['name'],
          image: docker_opts['Image'],
          container_type: 'volume'
        )
        volume_container.attributes_from_docker(resp)
        volume_container.save
      end

      volume_container
    end

    ##
    # @return [RpcClient]
    def client
      self.host_node.rpc_client(10)
    end
  end
end
