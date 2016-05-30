module HostNodes
  module Common

    # @param [Grid] grid
    def notify_grid(grid)
      Celluloid::Future.new {
        grid.host_nodes.connected.each do |node|
          notify_node(grid, node)
        end
      }
    end

    # @param [Grid] grid
    # @param [HostNode] node
    def notify_node(grid, node)
      plugger = Agent::NodePlugger.new(grid, node)
      plugger.send_node_info
    end
  end
end
