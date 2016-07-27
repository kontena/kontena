module Docker
  class ServiceTerminator

    attr_reader :host_node

    ##
    # @param [HostNode] host_node
    def initialize(host_node)
      @host_node = host_node
    end

    ##
    # @param [GridService] service
    # @param [Integer] instance_number
    # @param [Hash] opts
    def terminate_service_instance(service, instance_number, opts = {})
      if host_node.connected?
        self.request_terminate_service(service.id.to_s, instance_number, opts)
      end
    end

    ##
    # @param [String] service_id
    # @param [Integer] instance_number
    # @param [Hash] opts
    def request_terminate_service(service_id, instance_number, opts = {})
      client.request('/service_pods/terminate', service_id, instance_number, opts)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 30)
    end
  end
end
