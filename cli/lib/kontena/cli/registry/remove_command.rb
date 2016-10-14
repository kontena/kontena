module Kontena::Cli::Registry
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm unless forced?
      name = 'registry'

      registry = client.get("services/#{current_grid}/#{name}") rescue nil
      exit_with_error("Service #{name.colorize(:cyan)} does not exist") if registry.nil?

      spinner "Removing #{name.colorize(:cyan)} service " do
        client.delete("services/#{current_grid}/#{name}")
      end
    end
  end
end
