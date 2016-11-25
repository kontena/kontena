require_relative 'common'

module Kontena::Cli::Stacks
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common
    include Common::StackNameParam

    requires_current_account_token

    option ['-f', '--force'], :flag, "Don't ask questions"

    def execute
      unless force?
        if stack_version.nil?
          puts "About to delete an entire stack and all of its versions from the registry"
          confirm_command(stack_name)
        else
          confirm
        end
      end

      stacks_client.destroy(stack_name, stack_version)
      puts pastel.green("Stack #{stack_name}#{":#{stack_version}" if stack_version} deleted successfully")
    end
  end
end

