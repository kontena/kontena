require_relative 'helpers'

module GridServices
  class Stop < Mutations::Command
    include Helpers

    required do
      model :grid_service
    end

    optional do
      model :stack_deploy
    end

    def execute
      deploy_grid_service(grid_service, 'stopped', stack_deploy: stack_deploy)
    end
  end
end
