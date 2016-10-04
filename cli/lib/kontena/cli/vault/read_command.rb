module Kontena::Cli::Vault
  class ReadCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Secret name"

    def execute
      require_api_url
      require_current_grid

      token = require_token
      result = client(token).get("secrets/#{current_grid}/#{name}")
      puts "#{result['name']}:"
      puts "  created_at: #{result['created_at']}"
      puts "  value: #{result['value']}"
    end
  end
end
