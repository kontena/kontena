module GridServices
  class Restart < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def execute
      Celluloid::Future.new{
        self.restart_service_instances
      }
    end

    def restart_service_instances
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('restarting')
        self.grid_service.containers.scoped.each do |container|
          self.restart_service_instance(container.host_node, container.instance_number)
        end
        self.grid_service.set_state('running')
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end

    # @param [HostNode] node
    # @param [Integer] instance_number
    def restart_service_instance(node, instance_number)
      Docker::ServiceRestarter.new(node).restart_service_instance(self.grid_service, instance_number)
    end
  end
end
