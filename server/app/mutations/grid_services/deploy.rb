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
      boolean :force, default: false
    end

    def execute
      attrs = {
        :deploy_requested_at => Time.now.utc,
        :state => 'deploy_pending'
      }
      if self.force
        attrs[:updated_at] = Time.now.utc
      end
      self.grid_service.set(attrs)
      worker(:grid_service_scheduler).async.perform(self.grid_service.id)

      self.grid_service
    end
  end
end
