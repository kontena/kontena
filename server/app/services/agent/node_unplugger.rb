require_relative '../grid_scheduler'
require_relative '../event_stream/grid_event_notifier'

module Agent
  class NodeUnplugger
    include EventStream::GridEventNotifier
    include Logging

    attr_reader :node, :grid

    # @param [HostNode] node
    def initialize(node)
      @node = node
      @grid = node.grid
    end

    def unplug!
      begin
        self.update_node
      rescue => exc
        error exc.message
      end
    end

    def update_node
      node.update_attribute(:connected, false)
      self.trigger_grid_event(grid, 'node', 'update', HostNodeSerializer.new(node).to_hash)
      deleted_at = Time.now.utc
      node.containers.unscoped.where(:container_type.ne => 'volume').each do |c|
        c.with(safe: false).set(:deleted_at => deleted_at)
      end
    end
  end
end
