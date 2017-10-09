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

    def get_node(node_id)
      node = @grid.host_nodes.find_by(node_id: node_id)

      raise "Missing HostNode: #{node_id}" unless node

      return node
    end

    # @param [String] node_id
    def get(node_id)
      node = get_node(node_id)

      HostNodeSerializer.new(node).to_hash
    end

    # @param [String] node_id
    # @param [Hash] data
    def update(node_id, data)
      node = get_node(node_id)
      node.attributes_from_docker(data)
      node.updated = true # connection handshake complete after NodePlugger#plugin!
      node.save!
    end

    # @param [String] node_id
    # @param [Hash] data
    def stats(node_id, data)
      node = get_node(node_id)
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
      node.set(
        latest_stats: {
          memory: data['memory'],
          load: data['load'],
          filesystem: data['filesystem'],
          cpu: data['cpu']
        }
      )
    end
  end
end
