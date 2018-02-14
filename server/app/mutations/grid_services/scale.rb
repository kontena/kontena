require_relative 'helpers'

module GridServices
  class Scale < Mutations::Command
    include Helpers

    required do
      model :grid_service
      integer :instances
    end

    def execute
      grid_service.container_count = self.instances

      # without bumping the revision
      deploy_grid_service(grid_service, 'running')
    end
  end
end
