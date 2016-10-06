module Kontena::Cli::Registry
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master_token

    def execute
      warning "Support for 'kontena registry delete' will be dropped. Use 'kontena registry remove' instead."
      registry = client.get("services/#{current_grid}/registry") rescue nil
      exit_with_error("Docker Registry service does not exist") if registry.nil?
      client.delete("services/#{current_grid}/registry")
    end
  end
end
