module GridServices
  class Stop < Mutations::Command
    include AsyncHelper

    required do
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      async_thread do
        begin
          self.grid_service.set_state('stopped')
          self.stop_service_instances
        rescue => exc
          self.grid_service.set_state(prev_state)
          raise exc
        end
      end
    end

    def stop_service_instances
      self.grid_service.grid_service_instances.each do |i|
        i.set(desired_state: 'stopped')
        notify_node(i.host_node) if i.host_node
      end
    end

    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'stop')
    end
  end
end
