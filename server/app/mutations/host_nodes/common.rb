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

    # @return [String]
    def generate_token
      SecureRandom.base64(64)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Common inputs
      def common_inputs
        optional do
          array :labels
        end
      end
    end

    # @param node [HostNode]
    def set_common_params(host_node)
      host_node.labels = self.labels if self.labels
    end
  end
end
