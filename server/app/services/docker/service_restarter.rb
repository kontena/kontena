module Docker
  class ServiceRestarter

    attr_reader :host_node

    ##
    # @param [HostNode] host_node
    def initialize(host_node)
      @host_node = host_node
    end

    ##
    # @param [String] service_name
    def restart_service_instance(service_name)
      self.request_restart_service(service_name)
    end

    ##
    # @param [Hash] service_spec
    def request_restart_service(name)
      client.request('/service_pods/restart', name)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 5)
    end
  end
end
