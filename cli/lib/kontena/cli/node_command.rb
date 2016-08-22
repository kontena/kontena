require_relative 'nodes/list_command'
require_relative 'nodes/remove_command'
require_relative 'nodes/show_command'
require_relative 'nodes/update_command'
require_relative 'nodes/ssh_command'
require_relative 'nodes/label_command'

class Kontena::Cli::NodeCommand < Kontena::Command

  subcommand ["list","ls"], "List grid nodes", Kontena::Cli::Nodes::ListCommand
  subcommand "show", "Show node", Kontena::Cli::Nodes::ShowCommand
  subcommand "ssh", "Ssh into node", Kontena::Cli::Nodes::SshCommand
  subcommand "update", "Update node", Kontena::Cli::Nodes::UpdateCommand
  subcommand ["remove","rm"], "Remove node", Kontena::Cli::Nodes::RemoveCommand
  subcommand "label", "Node label specific commands", Kontena::Cli::Nodes::LabelCommand

  def execute
  end
end
