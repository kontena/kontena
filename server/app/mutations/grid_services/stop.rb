module GridServices
  class Stop < Mutations::Command
    required do
      model :grid_service
    end

    def execute
      self.grid_service.set_state('stopped')
      self.stop_service_instances
    rescue => exc
      add_error(:stop, :error, exc.message)
    end

    def stop_service_instances
      self.grid_service.grid_service_instances.each do |i|
        i.set(desired_state: 'stopped')
        notify_service_instance(i, 'stop')
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
