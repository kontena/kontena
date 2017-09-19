module GridServices
  class Start < Mutations::Command
    required do
      model :grid_service
    end

    def execute
      self.grid_service.set_state('running')
      self.start_service_instances
    rescue => exc
      add_error(:start, :error, exc.message)
    end

    def start_service_instances
      self.grid_service.grid_service_instances.each do |i|
        i.set(desired_state: 'running')
        notify_service_instance(i, 'start')
      end
    end

    # @param node [HostNode]
    # @param action [String]
    def notify_service_instance(service_instance, action)
      if service_instance.host_node
        service_instance.host_node.rpc_client.notify('/service_pods/notify_update', action)
      end
    end
  end
end
