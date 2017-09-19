module Agent
  class NodeUnplugger
    include Logging

    attr_reader :node

    # @param [HostNode] node
    def initialize(node)
      @node = node
    end

    # @param [Time] connected_at
    # @param [Integer] code websocket close
    # @param [String] reason websocket close
    def unplug!(connected_at, code, reason)
      connection = @node.websocket_connection
      self.update_node!(connected_at,
        connected: false,
        disconnected_at: Time.now.utc,
        websocket_connection: {
          opened: connection && connection.opened,
          close_code: code,
          close_reason: reason
        },
      )
      self.update_node_containers
      self.publish_update_event
    rescue => exc
      error exc
    end

    # @raise [RuntimeError] Node ... has already re-connected at ...
    def update_node!(connected_at, **attrs)
      connected_node = HostNode.where(:id => node.id, :connected_at => connected_at)
        .find_one_and_update({:$set => attrs})

      fail "Node #{@node} has already re-connected at #{@node.connected_at}" unless connected_node

      info "Disconnected node #{@node.to_path} connected at #{connected_at}"
    end

    def update_node_containers
      node.containers.unscoped.where(:container_type.ne => 'volume').set(:deleted_at => Time.now.utc)
    end

    def publish_update_event
      node.publish_update_event
    end
  end
end
