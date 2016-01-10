require_relative '../grid_scheduler'

module Agent
  class NodePlugger
    include Workers

    attr_reader :node, :grid

    # @param [Grid] grid
    # @param [HostNode] node
    def initialize(grid, node)
      @grid = grid
      @node = node
    end

    # @return [Celluloid::Future]
    def plugin!
      begin
        prev_seen_at = node.last_seen_at
        self.update_node
        self.send_master_info
        self.send_node_info
        self.reschedule_services(prev_seen_at)
      rescue => exc
        puts exc.message
      end
    end

    def update_node
      node.set(connected: true, last_seen_at: Time.now.utc)
    end

    def reschedule_services(prev_seen_at)
      return if !prev_seen_at.nil? && prev_seen_at > 2.minutes.ago.utc
      worker(:grid_scheduler).async.later(30, grid.id)
    end

    def send_node_info
      rpc_client.notify('/agent/node_info', node_info)
    end

    def send_master_info
      rpc_client.notify('/agent/master_info', {version: Server::VERSION})
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
