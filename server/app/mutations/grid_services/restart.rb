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
        self.grid_service.containers.scoped.each do |container|
          restarter_for(container).restart_container
        end
        self.grid_service.set_state('running')
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end

    ##
    # @param [Container] container
    # @return [Docker::ContainerRestarter]
    def restarter_for(container)
      Docker::ContainerRestarter.new(container)
    end
  end
end
