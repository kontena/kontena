module Rpc
  class NodeHandler

    def initialize(grid)
      @grid = grid
      @db_session = HostNode.collection.client.with(
        write: {
          w: 0, fsync: false, j: false
        }
      )
    end

    def get(id)
      node = @grid.host_nodes.find_by(node_id: id)
      if node
        HostNodeSerializer.new(node).to_hash
      else
        {}
      end
    end

    # @param [Hash] data
    def update(data)
      node_id = data['ID']
      node = @grid.host_nodes.find_by(node_id: node_id)

      raise "Missing HostNode: #{node_id}" unless node

      node.attributes_from_docker(data)
      node.updated = true # connection handshake complete after NodePlugger#plugin!
      node.save!
    end

    # @param [Hash] data
    def stats(data)
      node = @grid.host_nodes.find_by(node_id: data['id'])
      return unless node
      time = data['time'] ? Time.parse(data['time']) : Time.now.utc

      stat = {
        grid_id: @grid.id,
        host_node_id: node.id,
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
