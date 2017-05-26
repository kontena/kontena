module Kontena::Cli::Nodes::Labels
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NODE_ID", "Node id"

    # the command outputs id info only anyway, this is here strictly for ignoring purposes
    option ['-q', '--quiet'], :flag, "Output the identifying column only", hidden: true

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      node = client.get("nodes/#{current_grid}/#{node_id}")
      puts Array(node['labels']).join("\n")
    end
  end
end
