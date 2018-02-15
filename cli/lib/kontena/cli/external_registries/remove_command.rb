module Kontena::Cli::ExternalRegistries
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "NAME", "External registry name to remove"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm_command(name) unless forced?
      spinner "Removing #{pastel.cyan(name)} external-registry from #{pastel.cyan(current_grid)} grid " do
        client(token).delete("external_registries/#{current_grid}/#{name}")
      end
    end
  end
end
