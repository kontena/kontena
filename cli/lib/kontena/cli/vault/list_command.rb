module Kontena::Cli::Vault
  class ListCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require_api_url
      token = require_token
      result = client(token).get("grids/#{current_grid}/secrets")
      result['secrets'].each do |secret|
        puts secret['name']
      end
    end
  end
end
