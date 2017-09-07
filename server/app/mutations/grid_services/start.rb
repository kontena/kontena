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
        notify_node(i.host_node) if i.host_node
      end
    end

    # @param node [HostNode]
    def notify_node(node)
      node.rpc_client.notify('/service_pods/notify_update', 'start')
    end
  end
end
