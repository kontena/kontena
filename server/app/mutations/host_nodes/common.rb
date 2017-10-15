module HostNodes
  module Common

    # @param [Grid] grid
    def notify_grid(grid)
      grid.host_nodes.connected.each do |node|
        notify_node(grid, node)
      end
    end

    # @param [Grid] grid
    # @param [HostNode] node
    def notify_node(grid, node)
      plugger = Agent::NodePlugger.new(node)
      plugger.send_node_info
    end
  end
end
