module Kontena::Cli::Nodes
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    option ["-l", "--label"], "LABEL", "Node label", multivalued: true

    requires_current_master_token

    def execute
      node = client.get("grids/#{current_grid}/nodes/#{node_id}")
      data = {}
      data[:labels] = label_list if label_list
      spinner "Updating #{node_id.colorize(:cyan)} node" do
        client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
      end
    end
  end
end
