module GridServices
  class Deploy < Mutations::Command
    include Workers

    class ExecutionError < StandardError
    end

    required do
      model :grid_service
    end

    optional do
      model :current_user, class: User
      boolean :touch, default: true
    end

    def execute
      self.grid_service.set(
        :deploy_requested_at => Time.now.utc,
        :state => 'deploy_pending'
      )
      worker(:grid_service_scheduler).async.perform(self.grid_service.id)

      self.grid_service
    end
  end
end
