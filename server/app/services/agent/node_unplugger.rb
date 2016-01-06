require_relative '../grid_scheduler'

module Agent
  class NodeUnplugger
    include Workers

    attr_reader :node, :grid

    # @param [HostNode] node
    def initialize(node)
      @node = node
      @grid = node.grid
    end

    # @return [Celluloid::Future]
    def unplug!
      begin
        self.update_node
        self.reschedule_services
      rescue => exc
        puts exc.message
      end
    end

    def update_node
      node.update_attribute(:connected, false)
    end

    def reschedule_services
      worker(:grid_scheduler).async.later(60, grid_id)
    end
  end
end
