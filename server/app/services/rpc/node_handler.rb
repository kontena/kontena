require_relative 'fixnum_helper'

module Rpc
  class NodeHandler
    include Celluloid
    include FixnumHelper

    def initialize(grid)
      @grid = grid
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
      node.host_node_stats.create(
        grid_id: @grid.id,
        memory: data['memory'],
        load: data['load'],
        filesystem: data['filesystem']
      )
    end
  end
end
