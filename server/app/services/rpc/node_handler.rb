require_relative 'fixnum_helper'

module Rpc
  class NodeHandler
    include Celluloid
    include FixnumHelper

    def initialize(grid)
      @grid = grid
      @db_session = HostNode.collection.session.with(
        write: {
          w: 0, fsync: false, j: false
        }
      )
    end

    def get(id)
      node = @grid.host_nodes.find_by(node_id: id)
      if node
        template = Tilt.new('app/views/v1/host_nodes/_host_node.json.jbuilder')
        JSON.parse(template.render(nil, node: node))
      else
        {}
      end
    end

    # @param [Hash] data
    def update(data)
      node = @grid.host_nodes.find_by(node_id: data['ID'])
      if !node
        node = @grid.host_nodes.build
      end
      node.attributes_from_docker(data)
      node.save!
    end

    # @param [Hash] data
    def stats(data)
      node = @grid.host_nodes.find_by(node_id: data['id'])
      return unless node
      data = fixnums_to_float(data)
      time = data['time'] ? Time.parse(data['time']) : Time.now.utc

      stat = {
        grid_id: @grid.id,
        host_node_id: node.id,
        memory: data['memory'],
        load: data['load'],
        filesystem: data['filesystem'],
        usage: data['usage'],
        created_at: time
      }
      @db_session[:host_node_stats].insert(stat)
    end
  end
end
