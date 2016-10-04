module Kontena::Cli::Registry
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    def execute
       puts "DEPRECATION WARNING: Support for 'kontena registry delete' will be dropped. Use 'kontena registry remove' instead.".colorize(:red)

      require_api_url
      token = require_token

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      abort("Docker Registry service does not exist") if registry.nil?

      client(token).delete("services/#{current_grid}/registry")
    end
  end
end
