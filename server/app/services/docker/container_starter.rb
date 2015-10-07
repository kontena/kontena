module Docker
  class ContainerStarter

    attr_reader :container

    ##
    # @param [Container] container
    def initialize(container)
      @container = container
    end

    def start_container
      client.request('/containers/start', container.container_id)
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
