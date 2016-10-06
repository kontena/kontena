module Kontena::Cli::ExternalRegistries
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "External registry name to delete"

    requires_current_master_token

    def execute
      warning "Support for 'kontena external-registry delete' will be dropped. Use 'kontena external-registry remove' instead."
      client.delete("external_registries/#{current_grid}/#{name}")
    end
  end
end
