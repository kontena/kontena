module Kontena::Cli::Nodes
  class LabelCommand < Kontena::Command
    subcommand ["list", "ls"], "List node labels", load_subcommand('labels/list_command')
    subcommand "add", "Add label to node", load_subcommand('labels/add_command')
    subcommand ["remove", "rm"], "Remove label from node", load_subcommand('labels/remove_command')

    def execute
    end
  end
end
