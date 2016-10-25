module Kontena::Cli::Nodes::Labels
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE_ID", "Node id"
    parameter "LABEL", "Label"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("grids/#{current_grid}/nodes/#{node_id}")
      data = {}
      data[:labels] = node['labels'].to_a | [label]
      client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
    end
  end
end
