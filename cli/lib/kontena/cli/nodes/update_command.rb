module Kontena::Cli::Nodes
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    option ["-l", "--label"], "LABEL", "Node label", multivalued: true

    def execute
      require_api_url
      require_current_grid
      token = require_token


      node = client(token).get("grids/#{current_grid}/nodes/#{node_id}")
      data = {}
      data[:labels] = label_list if label_list
      client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
    end
  end
end
