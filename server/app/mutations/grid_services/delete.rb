module GridServices
  class Delete < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
    end

    def validate

      linked_to_services = self.grid_service.linked_to_services
      if linked_to_services.count > 0
        add_error(:service, :invalid, "Cannot delete service that is linked to another service (#{linked_to_services.map{|s| s.name}.join(', ')})")
      end
    end

    def execute
      prev_state = self.grid_service.state
      begin
        self.grid_service.set_state('deleting')
        self.grid_service.containers.scoped.each do |container|
          remover_for(container).remove_container
        end
        self.grid_service.containers.volumes.each do |container|
          remover_for(container).remove_container
        end
      rescue => exc
        self.grid_service.set_state(prev_state)
        raise exc
      end
      self.grid_service.destroy
    end

    ##
    # @param [Container] container
    # @return [Docker::ContainerRemover]
    def remover_for(container)
      Docker::ContainerRemover.new(container)
    end
  end
end
