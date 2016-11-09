module Kontena::Cli::Nodes::Labels
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE_ID", "Node id"

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      node = client.get("grids/#{current_grid}/nodes/#{node_id}")
      puts Array(node['labels']).join("\n")
    end
  end
end

