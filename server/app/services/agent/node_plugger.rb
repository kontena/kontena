require_relative '../grid_scheduler'

module Agent
  class NodePlugger

    attr_reader :node, :grid

    # @param [Grid] grid
    # @param [HostNode] node
    def initialize(grid, node)
      @grid = grid
      @node = node
    end

    # @return [Celluloid::Future]
    def plugin!
      Celluloid::Future.new {
        begin
          self.update_node
          self.reschedule_services
        rescue => exc
          puts exc.message
        end
      }
    end

    def update_node
      node.set(connected: true, last_seen_at: Time.now.utc)
    end

    def reschedule_services
      sleep 5
      GridScheduler.new(grid).reschedule
    end
  end
end
