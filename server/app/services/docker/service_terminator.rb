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
    def terminate_service_instance(service_name)
      if host_node.connected?
        self.request_terminate_service(service_name)
      end
    end

    ##
    # @param [Hash] service_spec
    def request_terminate_service(name)
      client.request('/service_pods/terminate', name)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 5)
    end
  end
end
