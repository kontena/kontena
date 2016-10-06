module Kontena::Cli::Registry
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?
      name = 'registry'

      registry = client(token).get("services/#{current_grid}/#{name}") rescue nil
      exit_with_error("Service #{name.colorize(:cyan)} does not exist") if registry.nil?

      spinner "Removing #{name.colorize(:cyan)} service " do
        client(token).delete("services/#{current_grid}/#{name}")
      end
    end
  end
end
