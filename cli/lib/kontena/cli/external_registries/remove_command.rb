module Kontena::Cli::ExternalRegistries
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "External registry name to remove"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm_command(name) unless forced?
      spinner "Removing #{name.colorize(:cyan)} external-registry from #{current_grid.colorize(:cyan)} grid " do
        client.delete("external_registries/#{current_grid}/#{name}")
      end
    end
  end
end
