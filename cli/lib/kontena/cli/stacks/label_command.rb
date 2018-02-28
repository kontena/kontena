module Kontena::Cli::Stacks
  class LabelCommand < Kontena::Command
    subcommand "add", "Add label to stack", load_subcommand('stacks/labels/add_command')

    def execute
    end
  end
end
