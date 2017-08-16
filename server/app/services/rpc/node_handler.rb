module Rpc
  class NodeHandler

    # @params [HostNode] node
    def initialize(node)
      @node = node
      @db_session = HostNode.collection.client.with(
        write: {
          w: 0, fsync: false, j: false
        }
      )
    end

    def node
      HostNode.find(@node.id).tap do |node|
        fail "Missing HostNode: #{@node.node_id}" unless node
      end
    end

    def get()
      HostNodeSerializer.new(self.node).to_hash
    end

    # @param [Hash] data
    def update(data)
      node = self.node
      node.attributes_from_docker(data)
      node.save!
    end

    # @param [Hash] data
    def stats(data)
      time = data['time'] ? Time.parse(data['time']) : Time.now.utc

      stat = {
        grid_id: @node.grid_id,
        host_node_id: @node.id,
        memory: data['memory'],
        load: data['load'],
        filesystem: data['filesystem'],
        usage: data['usage'],
        cpu: data['cpu'],
        network: data['network'],
        created_at: time
      }
      @db_session[:host_node_stats].insert_one(stat)
    end
  end
end
