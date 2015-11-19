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
          self.restart_service_instance(container.host_node, container.name)
        end
        self.grid_service.set_state('running')
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end

    def restart_service_instance(node, service_instance_name)
      Docker::ServiceRestarter.new(node).restart_service_instance(service_instance_name)
    end
  end
end
