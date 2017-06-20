module Kontena::Cli::Nodes
  class EnvCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NAME", "Node name"

    def grid_uri
      grid_uri = self.current_master['url'].sub('http', 'ws')
    end

    def execute
      node = client.get("nodes/#{current_grid}/#{name}")

      puts "KONTENA_URI=#{grid_uri}"
      puts "KONTENA_NODE_ID=#{node['id']}"
      puts "KONTENA_NODE_TOKEN=#{node['token']}"
    end
  end
end
