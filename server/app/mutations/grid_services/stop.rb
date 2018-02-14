require_relative 'helpers'

module GridServices
  class Stop < Mutations::Command
    include Helpers

    required do
      model :grid_service
    end

    def execute
      deploy_grid_service(grid_service, 'stopped')
    end
  end
end
