module Kontena::Cli::Nodes
  class LabelCommand < Kontena::Command
    subcommand ["list", "ls"], "List node labels", load_subcommand('nodes/labels/list_command')
    subcommand "add", "Add label to node", load_subcommand('nodes/labels/add_command')
    subcommand ["remove", "rm"], "Remove label from node", load_subcommand('nodes/labels/remove_command')
  end
end
