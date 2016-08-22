module Kontena::Cli::Nodes

  require_relative 'labels/add_command'
  require_relative 'labels/remove_command'

  class LabelCommand < Kontena::Command

    subcommand "add", "Add label to node", Labels::AddCommand
    subcommand ["remove", "rm"], "Remove label from node", Labels::RemoveCommand

    def execute
    end
  end
end
