module Kontena::Cli::Nodes::Labels
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE_NAME", "Node name", attribute_name: :node_id
    parameter "LABEL ...", "Labels", completion: "NODE_LABEL"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      node = client.get("nodes/#{current_grid}/#{node_id}")
      data = { labels: Array(node['labels']).reject {|label| label_list.include?(label) } }
      client.put("nodes/#{current_grid}/#{node['id']}", data)
    end
  end
end
