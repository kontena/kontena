module Docker
  class ServiceStarter

    attr_reader :host_node

    ##
    # @param [HostNode] host_node
    def initialize(host_node)
      @host_node = host_node
    end

    ##
    # @param [String] service_name
    def start_service_instance(service_name)
      self.request_start_service(service_name)
    end

    ##
    # @param [Hash] service_spec
    def request_start_service(name)
      client.request('/service_pods/start', name)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 5)
    end
  end
end
