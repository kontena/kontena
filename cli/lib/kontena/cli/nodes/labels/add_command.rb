module Kontena::Cli::Nodes::Labels
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE_ID", "Node id"
    parameter "LABEL ...", "Labels"

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
