module Kontena::Cli::Nodes
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      client(token).delete("grids/#{current_grid}/nodes/#{node_id}")
    end
  end
end
