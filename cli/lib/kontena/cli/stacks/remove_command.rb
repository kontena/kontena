require_relative 'common'

module Kontena::Cli::Stacks
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Removes a stack in a grid on Kontena Master"

    parameter "NAME", "Stack name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced
    option "--keep-dependencies", :flag, "Do not remove dependencies"

    requires_current_master
    requires_current_master_token

    def fetch_stack
      client.get("stacks/#{current_grid}/#{name}")
    end

    def confirm_remove(stack)
      if stack['parent']
        puts "#{pastel.yellow('Warning:')} The stack #{pastel.cyan(stack['parent']['name'])} depends on stack #{name}"
      end
      if stack['children'] && !stack['children'].empty?
        puts "#{pastel.yellow('Warning:')} The stack #{pastel.cyan(name)} has dependencies that will be removed:"
        stack['children'].each do |child|
          puts "- #{pastel.yellow(child['name'])}"
        end
      end
      confirm_command(name)
    end

    def execute
      stack = fetch_stack
      confirm_remove(stack) unless forced?
      unless keep_dependencies?
        stack.fetch('children', Hash.new).each do |child_stack|
          caret"Removing dependency #{pastel.cyan(child_stack['name'])}"
          Kontena.run!(['stack', 'remove', '--force', child_stack['name']])
        end
      end

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
