module Kontena::Cli::Nodes
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE", "Node name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("nodes/#{current_grid}/#{self.node}")

      if node['connected']
        exit_with_error "Node #{node['name']} is still online. You must terminate the node before removing it."
      end

      confirm_command(node_id) unless forced?

      spinner "Removing #{self.node.colorize(:cyan)} node from #{current_grid.colorize(:cyan)} grid " do
        client(token).delete("nodes/#{node['id']}")
      end
    end
  end
end
