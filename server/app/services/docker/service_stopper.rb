module Docker
  class ServiceStopper

    attr_reader :host_node

    ##
    # @param [HostNode] host_node
    def initialize(host_node)
      @host_node = host_node
    end

    ##
    # @param [String] service_name
    def stop_service_instance(service_name)
      self.request_stop_service(service_name)
    end

    ##
    # @param [Hash] service_spec
    def request_stop_service(name)
      client.request('/service_pods/start', name)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 5)
    end
  end
end
