module Kontena::Cli::Vault
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Secret name"
    parameter "VALUE", "Secret value"

    def execute
      require_api_url
      token = require_token
      data = {
          name: name,
          value: value
      }
      client(token).post("grids/#{current_grid}/secrets", data)
    end
  end
end
