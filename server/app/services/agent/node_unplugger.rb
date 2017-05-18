module Agent
  class NodeUnplugger
    include Logging

    attr_reader :node

    # @param [HostNode] node
    def initialize(node)
      @node = node
    end

    def unplug!
      info "disconnect node #{node}"
      self.update_node
      self.update_node_containers
      self.publish_update_event
    rescue => exc
      error exc
    end

    def update_node
      node.set(:connected => false)
    end

    def update_node_containers
      node.containers.unscoped.where(:container_type.ne => 'volume').set(:deleted_at => Time.now.utc)
    end

    def publish_update_event
      node.publish_update_event
    end
  end
end
