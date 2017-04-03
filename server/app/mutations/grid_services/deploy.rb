module GridServices
  class Deploy < Mutations::Command
    include Workers

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
      attrs = { deploy_requested_at: Time.now.utc, state: 'running' }
      attrs[:updated_at] = Time.now.utc if force
      grid_service.set(attrs)
      GridServiceDeploy.create(grid_service: grid_service)
    end
  end
end
