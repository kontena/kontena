require_relative 'common'

module Kontena::Cli::Stacks
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Removes a stack in a grid on Kontena Master"

    parameter "STACK_NAME", "Stack name", attribute_name: :name
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master
    requires_current_master_token

    def execute
      confirm_command(name) unless forced?
      spinner "Removing stack #{pastel.cyan(name)} " do
        remove_stack(name)
        wait_stack_removal(name)
      end
    end

    def remove_stack(name)
      client.delete("stacks/#{current_grid}/#{name}")
    end

    def wait_stack_removal(name)
      removed = false
      until removed == true
        begin
          client.get("stacks/#{current_grid}/#{name}")
          sleep 1
        rescue Kontena::Errors::StandardError => exc
          if exc.status == 404
            removed = true
          else
            raise exc
          end
        end
      end
    end
  end
end
