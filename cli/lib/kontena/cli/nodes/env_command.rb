module Kontena::Cli::Nodes
  class EnvCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "NAME", "Node name"
    option ['--token'], :flag, 'Only show token', default: false

    def grid_uri
      grid_uri = self.current_master['url'].sub('http', 'ws')
    end

    def execute
      token_node = client.get("nodes/#{current_grid}/#{name}/token")

      unless token_node['token']
        exit_with_error "Node #{name} was not created with a node token. Use `kontena grid env` instead"
      end

      if self.token?
        puts token_node['token']
      else
        puts "KONTENA_URI=#{grid_uri}"
        puts "KONTENA_NODE_TOKEN=#{token_node['token']}"
      end
    end
  end
end
