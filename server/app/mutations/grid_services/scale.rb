module GridServices
  class Scale < Mutations::Command
    include Workers

    required do
      model :grid_service
      integer :instances
    end

    def execute
      self.grid_service.set(:container_count => self.instances)
      GridServiceDeploy.create(grid_service: self.grid_service)
    end
  end
end
