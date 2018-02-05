require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class MakePrivateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Changes Stack visibility private in the Kontena Cloud Stack Registry"

    option '--force', :flag, "Don't ask for confirmation"

    requires_current_account_token

    def execute
      unless force?
        confirm("Change stack #{pastel.cyan(stack_name)} visibility to private?")
      end
      spinner "Updating Stack #{pastel.cyan(stack_name)} visibility to private" do
        stacks_client.make_private(stack_name)
      end
    end
  end
end
