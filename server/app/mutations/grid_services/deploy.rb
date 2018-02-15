require_relative 'helpers'

module GridServices
  class Deploy < Mutations::Command
    include Workers
    include Helpers

    ExecutionError = Class.new(StandardError)

    VALID_STATES = %w(initialized running deploying stopped)

    required do
      model :grid_service
    end

    optional do
      boolean :force, default: false
    end

    def validate
      unless VALID_STATES.include?(grid_service.state)
        add_error(:state, :invalid, "Cannot deploy because service state is #{grid_service.state}")
      end
    end

    def execute
      grid_service.deploy_requested_at = Time.now.utc
      grid_service.state = :running

      if self.force ? update_grid_service(grid_service, force: true) : save_grid_service(grid_service)
        GridServiceDeploy.create(grid_service: grid_service)
      end
    end
  end
end
