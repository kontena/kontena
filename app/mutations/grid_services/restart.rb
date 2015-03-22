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
        self.grid_service.containers.each do |container|
          Docker::ContainerRestarter.new(container).restart_container
        end
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end
  end
end
