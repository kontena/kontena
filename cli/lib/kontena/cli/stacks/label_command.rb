module Kontena::Cli::Stacks
  class LabelCommand < Kontena::Command
    subcommand "add", "Add label to stack", load_subcommand('stacks/labels/add_command')
    subcommand ["remove", "rm"], "Remove label from stack", load_subcommand('stacks/labels/remove_command')

    def execute
    end
  end
end
