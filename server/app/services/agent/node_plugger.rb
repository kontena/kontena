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
      self.update_node!(connected_at,
        connected: true,
        updated: false,
        last_seen_at: Time.now.utc,
        websocket_connection: {
          opened: true,
        },
      )
      info "Connected node #{@node.to_path} at #{connected_at}"
      self.publish_update_event
      self.send_node_info
    rescue => exc
      error exc
    end

    # Connection was rejected
    #
    # @param [Time] connected_at
    # @param [Integer] code websocket close
    # @param [String] reason websocket close
    def reject!(connected_at, code, reason)
      self.update_node!(connected_at,
        connected: false,
        updated: false,
        websocket_connection: {
          opened: false,
          close_code: code,
          close_reason: reason,
        },
      )
      info "Rejected connection for node #{@node.to_path} at #{connected_at} with code #{code}: #{reason}"
    rescue => exc
      error exc
    end

    # @raise [RuntimeError] Node ... has already re-connected at ...
    def update_node!(connected_at, **attrs)
      connected_node = HostNode.where(:id => node.id)
        .any_of({:connected_at => nil}, {:connected_at.lt => connected_at})
        .find_one_and_update({:$set => {connected_at: connected_at, **attrs}})

      fail "Node #{@node} has already re-connected at #{@node.connected_at}" unless connected_node
    end

    def publish_update_event
      node.publish_update_event
    end

    def send_node_info
      rpc_client.notify('/agent/node_info', Rpc::HostNodeSerializer.new(node).to_hash)
    end

    private

    # @return [RpcClient]
    def rpc_client
      RpcClient.new(node.node_id, 30)
    end
  end
end
