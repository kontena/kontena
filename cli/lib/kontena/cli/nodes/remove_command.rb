module Kontena::Cli::Nodes
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      require_current_grid
      token = require_token
      confirm_command(node_id) unless forced?

      client(token).delete("grids/#{current_grid}/nodes/#{node_id}")
    end
  end
end
