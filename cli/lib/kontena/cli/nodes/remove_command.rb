module Kontena::Cli::Nodes
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE_ID", "Node id"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm_command(node_id) unless forced?

      spinner "Removing #{node_id.colorize(:cyan)} node from #{current_grid.colorize(:cyan)} grid " do
        client.delete("grids/#{current_grid}/nodes/#{node_id}")
      end
    end
  end
end
