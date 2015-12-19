module Kontena::Cli::Vault
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Secret name"

    def execute
      require_api_url
      token = require_token
      client(token).delete("secrets/#{current_grid}/#{name}")
    end
  end
end
