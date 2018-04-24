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
        provider = Array(node["labels"]).find{ |l| l.start_with?('provider=')}.to_s.split('=').last
        if node['connected'] && provider
          plugin = provider == 'kontena' ? 'cloud' : provider
          exit_with_error "Node #{node['name']} is still connected. You should terminate the node instead: kontena #{plugin} node terminate #{node['name']}"
        elsif node['connected']
          exit_with_error "Node #{node['name']} is still connected. You must terminate the node before removing it"
        else
          warning "Removing a node from the grid does not terminate the host machine from any cloud provider, so your cloud provider may continue to bill you for the machine until you terminate it"
        end

        confirm_command(node_name) unless forced?

        spinner "Removing #{pastel.cyan(node_name)} node from #{pastel.cyan(current_grid)} grid " do
          client(token).delete("nodes/#{node['id']}")
        end
      end
    end
  end
end
