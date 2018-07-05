require_relative 'helpers'

module GridServices
  class Deploy < Mutations::Command
    include Helpers

    required do
      model :grid_service
    end

    optional do
      boolean :force, default: false
    end

    def execute
      deploy_grid_service(grid_service, 'running', force: self.force)
    end
  end
end
