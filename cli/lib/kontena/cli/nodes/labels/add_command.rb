module Kontena::Cli::Nodes::Labels
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE_NAME", "Node name", attribute_name: :node_id
    parameter "LABEL ...", "Labels", completion: "NODE_LABEL"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      node = client.get("nodes/#{current_grid}/#{node_id}")
      data = { labels: (Array(node['labels']) + label_list).uniq }
      client.put("nodes/#{current_grid}/#{node_id}", data)
    end
  end
end
