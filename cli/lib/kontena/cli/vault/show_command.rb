module Kontena::Cli::Vault
  class ShowCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Secret name"

    def execute
      require_api_url
      token = require_token
      result = client(token).get("secrets/#{current_grid}/#{name}")
      puts "name: #{result['name']}"
      puts "value: #{result['value']}"
    end
  end
end
