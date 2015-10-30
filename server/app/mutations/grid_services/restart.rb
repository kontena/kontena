module GridServices
  class Restart < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('restarting')
        Celluloid::Future.new{
          self.restart_service_instances
        }
        self.grid_service.set_state('running')
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end

    def restart_service_instances
      self.grid_service.containers.scoped.each do |container|
        Docker::ServiceRestarter.new(container.host_node).restart_service_instance(container.name)
      end
    end
  end
end
