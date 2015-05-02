module Docker
  class ContainerRemover

    attr_reader :container

    ##
    # @param [Container] container
    def initialize(container)
      @container = container
    end

    def remove_container(remove_opts = {v: true, force: true})
      begin
        if host_node
          if container.running?
            client.request('/containers/stop', container.container_id, {})
          end
          client.request('/containers/delete', container.container_id, remove_opts)
        end
      rescue RpcClient::Error => exc
        unless exc.code == 404
          raise exc
        end
      end
      container.destroy
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
