module GridServices
  class Deploy < Mutations::Command
    include Workers

    class ExecutionError < StandardError
    end

    VALID_STATES = %w(initialized running stopped)

    required do
      model :grid_service
    end

    optional do
      model :current_user, class: User
      boolean :force, default: false
    end

    def validate
      unless VALID_STATES.include?(grid_service.state)
        add_error(:state, :invalid, "Cannot deploy because service state is #{grid_service.state}")
      end
    end

    def execute
      attrs = { deploy_requested_at: Time.now.utc, state: 'running' }
      if self.force
        attrs[:updated_at] = Time.now.utc
      end
      self.grid_service.set(attrs)
      GridServiceDeploy.create(grid_service: self.grid_service)

      self.grid_service
    end
  end
end
