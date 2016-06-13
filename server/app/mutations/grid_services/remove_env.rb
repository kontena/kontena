module GridServices
  class RemoveEnv < Mutations::Command
    required do
      model :grid_service
      string :env
    end

    def execute
      self.grid_service.env.dup.each do |e|
        k, v = e.split("=", 2)
        if k == env
          self.grid_service.env.delete(e)
        end
      end
      if self.grid_service.changed?
        self.grid_service.revision += 1
      end
      self.grid_service.save
    end
  end
end
