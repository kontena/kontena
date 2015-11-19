module GridServices
  class Stop < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      Celluloid::Future.new{
        begin
          self.grid_service.set_state('stopping')
          self.stop_service_instances
          self.grid_service.set_state('stopped')
        rescue => exc
          self.grid_service.set_state(prev_state)
          raise exc
        end
      }
    end

    def stop_service_instances
      self.grid_service.containers.each do |container|
        Docker::ServiceStopper.new(container.host_node).stop_service_instance(container.name)
      end
    end
  end
end
