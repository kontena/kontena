require_relative '../grid_scheduler'
require_relative '../event_stream/grid_event_notifier'

module Agent
  class NodeUnplugger
    include EventStream::GridEventNotifier
    attr_reader :node, :grid

    # @param [HostNode] node
    def initialize(node)
      @node = node
      @grid = node.grid
    end

    # @return [Celluloid::Future]
    def unplug!
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
      node.update_attribute(:connected, false)
      self.trigger_grid_event(grid, 'node', 'update', HostNodeSerializer.new(node).to_hash)
    end

    def reschedule_services
      sleep 5
      GridScheduler.new(grid).reschedule
    end
  end
end
