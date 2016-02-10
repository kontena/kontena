module Kontena::Cli::Registry
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common

    def execute
      require_api_url
      token = require_token

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      abort("Docker Registry service does not exist") if registry.nil?

      client(token).delete("services/#{current_grid}/registry")
    end
  end
end
