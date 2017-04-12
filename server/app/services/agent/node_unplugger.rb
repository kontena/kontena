module Agent
  class NodeUnplugger
    include Logging

    attr_reader :node

    # @param [HostNode] node
    def initialize(node)
      @node = node
    end

    def unplug!
      logger.info "disconnect node #{node.name || node.node_id}"

      begin
        self.update_node
        self.publish_update_event
      rescue => exc
        error exc.message
      end
    end

    def update_node
      node.set(:connected => false)
      deleted_at = Time.now.utc
      node.containers.unscoped.where(:container_type.ne => 'volume').each do |c|
        c.with(safe: false).set(:deleted_at => deleted_at)
      end
    end

    def publish_update_event
      node.publish_update_event
    end
  end
end
