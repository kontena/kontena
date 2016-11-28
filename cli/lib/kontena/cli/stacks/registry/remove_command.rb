require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::StackNameParam

    banner "Removes a stack (or version) from the stack registry. Use user/stack_name or user/stack_name:version."

    parameter "[FILENAME]", "Stack file path"

    option ['-f', '--force'], :flag, "Force delete"

    requires_current_account_token

    def execute
      unless force?
        if stack_name.include?(':')
          puts "About to delete #{stack_name} from the registry"
          confirm
        else
          puts "About to delete an entire stack and all of its versions from the registry"
          confirm_command(stack_name)
        end
      end
      stacks_client.destroy(stack_name)
      puts pastel.green("Stack #{stack_name} deleted successfully")
    end
  end
end
