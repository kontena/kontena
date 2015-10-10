module GridServices
  class AddEnv < Mutations::Command
    required do
      model :grid_service
      string :env
    end

    def execute
      self.grid_service.env << env
      self.grid_service.save
    end
  end
end
