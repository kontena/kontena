require_relative 'common'

module Kontena::Cli::Stacks
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token

      confirm_command(name) unless forced?
      spinner "Removing stack #{pastel.cyan(name)} " do
        remove_stack(token, name)
        wait_stack_removal(token, name)
      end
    end

    def remove_stack(token, name)
      client(token).delete("stacks/#{current_grid}/#{name}")
    end

    def wait_stack_removal(token, name)
      removed = false
      until removed == true
        begin
          client(token).get("stacks/#{current_grid}/#{name}")
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
