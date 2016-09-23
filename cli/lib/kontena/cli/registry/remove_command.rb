module Kontena::Cli::Registry
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?

      registry = client(token).get("services/#{current_grid}/registry") rescue nil
      abort("Docker Registry service does not exist") if registry.nil?

      client(token).delete("services/#{current_grid}/registry")
    end
  end
end
