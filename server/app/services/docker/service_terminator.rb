module Docker
  class ServiceTerminator

    attr_reader :host_node

    ##
    # @param [HostNode] host_node
    def initialize(host_node)
      @host_node = host_node
    end

    ##
    # @param [String] service_name
    # @param [Hash] opts
    def terminate_service_instance(service_name, opts = {})
      if host_node.connected?
        self.request_terminate_service(service_name, opts)
      end
    end

    ##
    # @param [String] name
    # @param [Hash] opts
    def request_terminate_service(name, opts = {})
      client.request('/service_pods/terminate', name, opts)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 5)
    end
  end
end
