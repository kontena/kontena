module Kontena::Cli::Nodes
  class EvacuateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      spinner "Putting #{node_id.colorize(:cyan)} node into evacuation mode" do
        client.post("nodes/#{current_grid}/#{node_id}/evacuate", {})
      end
    end
  end
end
