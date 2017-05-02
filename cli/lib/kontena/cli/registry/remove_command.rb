module Kontena::Cli::Registry
  class RemoveCommand < Kontena::Command

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm unless forced?
      name = 'registry'

      registry = client(token).get("stacks/#{current_grid}/#{name}") rescue nil
      exit_with_error("Stack #{name.colorize(:cyan)} does not exist") if registry.nil?

      spinner "Removing #{name.colorize(:cyan)} stack " do
        client(token).delete("stacks/#{current_grid}/#{name}")
      end
    end
  end
end
