module GridServices
  class Restart < Mutations::Command
    required do
      model :grid_service
    end

    def execute
      self.restart_service_instances
    rescue => exc
      add_error(:restart, :error, exc.message)
    end

    def restart_service_instances
      self.grid_service.grid_service_instances.each do |i|
        restart_service_instance(i)
      end
    end

    # @param service_instance [GridServiceInstance]
    def restart_service_instance(service_instance)
      if service_instance.host_node
        rpc_client = service_instance.host_node.rpc_client
        rpc_client.notify('/service_pods/restart', service_instance.grid_service.id.to_s, service_instance.instance_number)
      end
    end
  end
end
