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
      client = self.host_node.rpc_client(10)

      container = Container.create(
        host_node: self.host_node,
        grid: self.grid_service.grid,
        name: name,
        image: self.grid_service.image,
        deploy_rev: deploy_rev,
        overlay_cidr: SecureRandom.hex(32)
      )
      ContainerOverlayConfig.reserve_overlay_cidr(self.grid_service, container)
      docker_opts = ContainerOptsBuilder.build_opts(self.grid_service, container)
      ContainerOverlayConfig.modify_labels(container, docker_opts['Labels'])
      resp = request_create_container(client, docker_opts)
      sync_container_with_docker_response(container, resp)
      container
    rescue => exc
      container.destroy if container
      raise exc
    end

    ##
    # @param [RpcClient] client
    # @param [Hash] docker_opts
    # @return [Container]
    def request_create_container(client, docker_opts)
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
  end
end
