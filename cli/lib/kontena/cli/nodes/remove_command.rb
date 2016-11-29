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

      spinner "Removing #{node_id.colorize(:cyan)} node from #{current_grid.colorize(:cyan)} grid " do
        client(token).delete("nodes/#{current_grid}/#{node_id}")
      end
    end
  end
end
