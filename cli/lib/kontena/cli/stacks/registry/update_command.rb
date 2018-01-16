require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common
    include Kontena::Cli::Stacks::Common::RegistryNameParam

    banner "Changes stack settings on registry"

    option '--make-private', :flag, "Change visibility to private"
    option '--make-public', :flag, "Change visibility to ppublic"

    requires_current_account_token

    def execute
      if make_private?
        stacks_client.make_private(stack_name)
        puts "Stack #{pastel.cyan(stack_name)} is now private"
      elsif make_public?
        stacks_client.make_public(stack_name)
        puts "Stack #{pastel.cyan(stack_name)} is now public"
      else
        exit_with_error "Nothing to do"
      end
    end
  end
end

