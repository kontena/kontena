module Docker
  class ContainerRestarter

    attr_reader :container

    ##
    # @param [Container] container
    def initialize(container)
      @container = container
    end

    def restart_container
      begin
        if container.running?
          client.request('/containers/restart', container.container_id)
        else
          client.request('/containers/start', container.container_id, {})
        end
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
