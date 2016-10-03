module Kontena::Cli::ExternalRegistries
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "External registry name to remove"

    def execute
      require_api_url
      token = require_token
      client(token).delete("external_registries/#{current_grid}/#{name}")
    end
  end
end
