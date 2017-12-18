module Kontena::Cli::Vault
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Secret name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced
    option "--silent", :flag, "Reduce output verbosity"

    def execute
      require_api_url
      require_current_grid
      confirm_command(name) unless forced?

      token = require_token
      vspinner "Removing #{pastel.cyan(name)} from the vault " do
        client(token).delete("secrets/#{current_grid}/#{name}")
      end
    end
  end
end
