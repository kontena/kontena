module GridServices
  class Delete < Mutations::Command
    include Workers

    required do
      model :current_user, class: User
      model :grid_service
    end

    def validate
      if self.grid_service.deploying?
        add_error(:service, :invalid, "Cannot delete service because it's currently being deployed")
        return
      end
      linked_to_services = self.grid_service.linked_to_services
      if linked_to_services.count > 0
        add_error(:service, :invalid, "Cannot delete service that is linked to another service (#{linked_to_services.map{|s| s.name}.join(', ')})")
      end
    end

    def execute
      worker(:grid_service_remove).async.perform(self.grid_service.id)
    end
  end
end
