module Kontena::Cli::Nodes::Labels
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    parameter "LABEL", "Label"

    requires_current_master_token

    def execute
      node = client.get("grids/#{current_grid}/nodes/#{node_id}")
      data = {}
      data[:labels] = node['labels'].to_a | [label]
      client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
    end
  end
end
