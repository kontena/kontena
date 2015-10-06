module Docker
  class ContainerInspector

    attr_reader :container

    ##
    # @param [Container] container
    def initialize(container)
      @container = container
    end

    def inspect_container
      begin
        response = client.request('/containers/inspect', container.container_id, {})
        return response
      rescue RpcClient::Error => exc
        unless exc.code == 404
          raise exc
        end
      end
    end

    private

    ##
    # @return [HostNode]
    def host_node
      self.container.host_node
    end

    ##
    # @return [RpcClient]
    def client
      host_node.rpc_client
    end
  end
end
