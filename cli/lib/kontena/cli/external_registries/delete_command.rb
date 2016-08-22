module Kontena::Cli::ExternalRegistries
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "External registry name to delete"

    def execute
       puts "DEPRECATION WARNING: Support for 'kontena external-registry delete' will be dropped. Use 'kontena external-registry remove' instead.".colorize(:red)
      require_api_url
      token = require_token
      client(token).delete("external_registries/#{current_grid}/#{name}")
    end
  end
end
