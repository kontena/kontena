module GridServices
  class Scale < Mutations::Command
    required do
      model :current_user, class: User
      model :grid_service
      integer :instances
    end

    def execute
      self.grid_service.set(:container_count => self.instances)
      GridServices::Deploy.run(
        grid_service: self.grid_service
      )
    end
  end
end
