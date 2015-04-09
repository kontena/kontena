module GridServices
  class Start < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def execute
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('starting')
        self.grid_service.containers.scoped.each do |container|
          starter_for(container).start_container
        end
        self.grid_service.set_state('running')
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
    end

    ##
    # @param [Container] container
    # @return [Docker::ContainerStarter]
    def starter_for(container)
      Docker::ContainerStarter.new(container)
    end
  end
end
