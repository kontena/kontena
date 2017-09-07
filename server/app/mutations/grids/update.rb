require_relative 'common'

module Grids
  class Update < Mutations::Command
    include Common

    required do
      model :grid
      model :user
    end

    common_validations

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_update?(grid)

      validate_common
    end

    def execute
      execute_common(self.grid)

      unless self.grid.save
        self.grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      self.notify_nodes
      self.reschedule_grid(self.grid) if self.default_affinity

      self.grid
    end

    def notify_nodes
      grid.host_nodes.connected.each do |node|
        plugger = Agent::NodePlugger.new(node)
        plugger.send_node_info
      end
    end

    # @return [Celluloid::Proxy::Cell<GridSchedulerJob>]
    def grid_scheduler
      Celluloid::Actor[:grid_scheduler_job]
    end

    # @param grid [Grid]
    def reschedule_grid(grid)
      grid_scheduler.async.reschedule_grid(grid)
    end
  end
end
