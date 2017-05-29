require_relative '../../serializers/rpc/host_node_serializer'

module Agent
  class NodePlugger
    include Logging

    attr_reader :node

    # @param [HostNode] node
    def initialize(node)
      @node = node
    end

    # @param [Time] connected_at
    def plugin!(connected_at)
      self.update_node! connected_at
      self.publish_update_event
      self.send_master_info
      self.send_node_info
    rescue => exc
      error exc
    end

    # @raise [RuntimeError] Node ... has already re-connected at ...
    def update_node!(connected_at)
      connected_node = HostNode.where(:id => node.id)
        .any_of({:connected_at => nil}, {:connected_at.lt => connected_at})
        .find_one_and_update({:$set => {connected: true, last_seen_at: Time.now.utc, connected_at: connected_at}})

      fail "Node #{@node} has already re-connected at #{@node.connected_at}" unless connected_node

      info "Connected node #{@node.to_path} at #{connected_at}"
    end

    def publish_update_event
      node.publish_update_event
    end

    def send_node_info
      rpc_client.notify('/agent/node_info', Rpc::HostNodeSerializer.new(node).to_hash)
    end

    def send_master_info
      rpc_client.notify('/agent/master_info', {version: Server::VERSION})
    end

    private

    # @return [RpcClient]
    def rpc_client
      RpcClient.new(node.node_id, 30)
    end
  end
end
