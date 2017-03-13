module GridServices
  class Delete < Mutations::Command
    include Workers

    required do
      model :grid_service
    end

    def validate
      linked_from_services = self.grid_service.linked_from_services
      if linked_from_services.count > 0
        add_error(:service, :invalid, "Cannot delete service that is linked to another service (#{linked_from_services.map{|s| s.name}.join(', ')})")
      end
    end

    def execute
      nodes = self.grid_service.grid_service_instances.map{ |i| i.host_node }
      notify_lb_remove if self.grid_service.linked_to_load_balancer?
      self.grid_service.destroy
      nodes.each do |node|
        notify_node(node) if node
      end
    end

    # @param [HostNode] node
    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'terminate')
    end

    def notify_lb_remove
      lb = self.grid_service.linked_to_load_balancers[0]
      return unless lb
      service_instance = self.grid_service.grid_service_instances.to_a.find { |i|
        i.host_node && i.host_node.connected?
      }
      return unless service_instance

      lb_name = lb.qualified_name
      service_pod = Rpc::ServicePodSerializer.new(service_instance).to_hash
      RpcClient.new(service_instance.host_node.node_id).request(
        '/load_balancers/remove_service', service_pod
      )
    end
  end
end
