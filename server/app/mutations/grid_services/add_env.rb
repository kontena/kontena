require_relative 'helpers'

module GridServices
  class AddEnv < Mutations::Command
    include Helpers

    required do
      model :grid_service
      string :env
    end

    def execute
      self.grid_service.env << env

      update_grid_service(grid_service)
    end
  end
end
