module Kontena::Cli::Vault
  class ReadCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Secret name"

    requires_current_master_token

    def execute
      result = client.get("secrets/#{current_grid}/#{name}")
      puts "#{result['name']}:"
      puts "  created_at: #{result['created_at']}"
      puts "  value: #{result['value']}"
    end
  end
end
