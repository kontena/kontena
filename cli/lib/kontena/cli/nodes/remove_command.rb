module Kontena::Cli::Nodes
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NODE ...", "Node name", attribute_name: :nodes
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      require_current_grid
      token = require_token

      nodes.each do |node_name|
        node = client(token).get("nodes/#{current_grid}/#{node_name}")

        if node['has_token'] && node['connected']
          warning "Node #{node['name']} is still connected using a node token, but will be force-disconnected"
        elsif node['connected']
          exit_with_error "Node #{node['name']} is still connected using a grid token. You must terminate the node before removing it."
        end

        confirm_command(node_name) unless forced?

        spinner "Removing #{pastel.cyan(node_name)} node from #{pastel.cyan(current_grid)} grid " do
          client(token).delete("nodes/#{node['id']}")
        end
      end
    end
  end
end
