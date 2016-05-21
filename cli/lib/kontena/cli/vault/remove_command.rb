module Kontena::Cli::Vault
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Secret name"
    option "--confirm", :flag, "Confirm remove", default: false, attribute_name: :confirmed

    def execute
      require_api_url
      require_current_grid
      confirm_command(name) unless confirmed?

      token = require_token
      client(token).delete("secrets/#{current_grid}/#{name}")
    end
  end
end
