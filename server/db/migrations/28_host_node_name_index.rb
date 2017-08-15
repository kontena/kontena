class HostNodeNameIndex < Mongodb::Migration
  def self.up
    # TODO: assign name to any nodes that are missing a name
    HostNode.create_indexes
  end
end
