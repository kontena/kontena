module GridServices
  class Stop < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('stopping')
        self.grid_service.containers.each do |container|
          Docker::ContainerStopper.new(container).stop_container
        end
        self.grid_service.set_state('stopped')
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end
  end
end
