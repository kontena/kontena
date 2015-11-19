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
          self.send_node_info
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

    def send_node_info
      rpc_client.request('/agent/node_info', node_info)
    end

    private

    # @return [Hash]
    def node_info
      template = Tilt.new('app/views/v1/host_nodes/_host_node.json.jbuilder')
      JSON.parse(template.render(nil, node: node))
    end

    # @return [RpcClient]
    def rpc_client
      RpcClient.new(node.node_id, 5)
    end
  end
end
