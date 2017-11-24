require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Removes a stack (or version) from the stack registry. Use user/stack_name or user/stack_name:version."

    option ['-f', '--force'], :flag, "Force delete"

    requires_current_account_token

    def execute
      unless force?
        if stack_name.version
          puts "About to delete #{pastel.cyan("#{stack_name}")} from the stacks registry"
          confirm
        else
          puts "About to delete an entire stack and all of its versions from the stacks registry"
          confirm_command(stack_name)
        end
      end
      spinner "Removing #{pastel.cyan(stack_name)} from the registry" do
        stacks_client.destroy(stack_name.stack_name, stack_name.version)
      end
    end
  end
end
