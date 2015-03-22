module Docker
  class ContainerExecutor

    attr_reader :container

    ##
    # @param [Container] container
    def initialize(container)
      @container = container
    end

    def exec_in_container(cmd)
      begin
        response = client.request('/containers/exec', container.container_id, cmd, {})
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
