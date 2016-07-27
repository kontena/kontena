module Docker
  class ServiceRestarter

    attr_reader :host_node

    # @param [HostNode] host_node
    def initialize(host_node)
      @host_node = host_node
    end

    # @param [GridService] service
    # @param [Integer] instance_number
    def restart_service_instance(service, instance_number)
      self.request_restart_service(service.id.to_s, instance_number)
    end

    # @param [String] service_id
    # @param [Integer] instance_number
    def request_restart_service(service_id, instance_number)
      client.request('/service_pods/restart', service_id, instance_number)
    end

    ##
    # @return [RpcClient]
    def client
      RpcClient.new(host_node.node_id, 30)
    end
  end
end
