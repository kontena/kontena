module GridServices
  class Start < Mutations::Command
    include AsyncHelper

    required do
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      async_thread do
        begin
          self.grid_service.set_state('running')
          self.start_service_instances
        rescue => exc
          self.grid_service.set_state(prev_state)
          raise exc
        end
      end
    end

    def start_service_instances
      self.grid_service.grid_service_instances.each do |i|
        i.set(desired_state: 'running')
        notify_node(i.host_node) if i.host_node
      end
    end

    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'start')
    end
  end
end
