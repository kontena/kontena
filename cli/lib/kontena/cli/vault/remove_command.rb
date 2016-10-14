module Kontena::Cli::Vault
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Secret name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm_command(name) unless forced?
      spinner "Removing #{name.colorize(:cyan)} from the vault " do
        client.delete("secrets/#{current_grid}/#{name}")
      end
    end
  end
end
