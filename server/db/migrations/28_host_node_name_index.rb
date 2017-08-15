class HostNodeNameIndex < Mongodb::Migration
  def self.up
    HostNode.each do |node|
      next if node.name

      if node.node_number
        node.name = "node-#{node.node_number}"
      else
        node.name = "unknown-node"
        node.ensure_unique_name
      end

      node.save!
    end

    HostNode.create_indexes
  end
end
