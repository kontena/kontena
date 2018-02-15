class HostNodeIndexes < Mongodb::Migration
  def self.up

    # Make sure each node has proper node_number and name
    HostNode.each do |node|
      unless node.node_number
        node.set(node_number: node.grid.free_node_numbers.first)
      end

      unless node.name
        node.set(name: "node-#{node.node_number}")
      end
    end

    # Drop old indexes before re-creating
    HostNode.collection.indexes.drop_one('grid_id_1_node_number_1') rescue nil
    HostNode.collection.indexes.drop_one('node_id_1') rescue nil

    HostNode.create_indexes
  end
end
