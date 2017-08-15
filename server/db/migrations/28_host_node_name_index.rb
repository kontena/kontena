class HostNodeNameIndex < Mongodb::Migration
  def self.up
    HostNode.create_indexes
  end
end
