class HostNodeIndexes < Mongodb::Migration
  def self.up
    HostNode.collection.indexes.drop_one('node_id_1')
    HostNode.create_indexes
  end
end
