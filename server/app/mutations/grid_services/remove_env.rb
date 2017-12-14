require_relative 'helpers'

module GridServices
  class RemoveEnv < Mutations::Command
    include Helpers

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

      update_grid_service(grid_service)
    end
  end
end
