require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class MakePublicCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Changes Stack visibility private in the Kontena Cloud Stack Registry"

    option '--force', :flag, "Don't ask for confirmation"

    requires_current_account_token

    def execute
      unless force?
        confirm("Change stack #{pastel.cyan(stack_name)} visibility to public?")
      end
      spinner "Updating Stack #{pastel.cyan(stack_name)} visibility to public" do
        stacks_client.make_public(stack_name)
      end
    end
  end
end
