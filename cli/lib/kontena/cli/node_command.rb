require_relative 'nodes/list_command'
require_relative 'nodes/remove_command'
require_relative 'nodes/show_command'
require_relative 'nodes/update_command'

class Kontena::Cli::NodeCommand < Clamp::Command

  subcommand "list", "List grid nodes", Kontena::Cli::Nodes::ListCommand
  subcommand "show", "Show node", Kontena::Cli::Nodes::ShowCommand
  subcommand "update", "Update node", Kontena::Cli::Nodes::UpdateCommand
  subcommand "remove", "Remove node", Kontena::Cli::Nodes::RemoveCommand

  def execute
  end
end
