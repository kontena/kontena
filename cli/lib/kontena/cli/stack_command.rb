require_relative 'stacks/create_command'
require_relative 'stacks/remove_command'
require_relative 'stacks/deploy_command'
require_relative 'stacks/update_command'
require_relative 'stacks/list_command'
require_relative 'stacks/show_command'

class Kontena::Cli::StackCommand < Kontena::Command

  subcommand "create", "Create stack", Kontena::Cli::Stacks::CreateCommand
  subcommand ["ls", "list"], "List stacks", Kontena::Cli::Stacks::ListCommand
  subcommand "show", "Show stack details", Kontena::Cli::Stacks::ShowCommand
  subcommand "update", "Update stack", Kontena::Cli::Stacks::UpdateCommand
  subcommand "deploy", "Deploy Kontena stack", Kontena::Cli::Stacks::DeployCommand
  subcommand ["remove","rm"], "Remove stack", Kontena::Cli::Stacks::RemoveCommand
  
  def execute

  end
end
