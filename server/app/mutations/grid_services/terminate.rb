require_relative 'helpers'

module GridServices
  class Terminate < Mutations::Command
    include Helpers

    required do
      model :grid_service
    end

    optional do
      model :stack_deploy
    end

    def execute
      deploy_grid_service(grid_service, 'terminated', stack_deploy: stack_deploy)
    end
  end
end
