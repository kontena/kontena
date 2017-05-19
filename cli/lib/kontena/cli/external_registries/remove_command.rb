module Kontena::Cli::ExternalRegistries
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "EXTERNAL_REGISTRY_NAME", "External registry name to remove", attribute_name: :name
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm_command(name) unless forced?
      spinner "Removing #{name.colorize(:cyan)} external-registry from #{current_grid.colorize(:cyan)} grid " do
        client(token).delete("external_registries/#{current_grid}/#{name}")
      end
    end
  end
end
