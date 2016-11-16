require_relative 'stacks/create_command'
require_relative 'stacks/remove_command'
require_relative 'stacks/deploy_command'
require_relative 'stacks/update_command'
require_relative 'stacks/list_command'
require_relative 'stacks/show_command'
require_relative 'stacks/build_command'
require_relative 'stacks/monitor_command'
require_relative 'stacks/logs_command'

class Kontena::Cli::StackCommand < Kontena::Command

  subcommand "create", "Create stack", Kontena::Cli::Stacks::CreateCommand
  subcommand "build", "Build stack file images", Kontena::Cli::Stacks::BuildCommand
  subcommand ["ls", "list"], "List stacks", Kontena::Cli::Stacks::ListCommand
  subcommand "show", "Show stack details", Kontena::Cli::Stacks::ShowCommand
  subcommand "update", "Update stack", Kontena::Cli::Stacks::UpdateCommand
  subcommand "deploy", "Deploy stack", Kontena::Cli::Stacks::DeployCommand
  subcommand "logs", "Show stack logs from stack services", Kontena::Cli::Stacks::LogsCommand
  subcommand "monitor", "Monitor stack", Kontena::Cli::Stacks::MonitorCommand
  subcommand ["remove","rm"], "Remove stack", Kontena::Cli::Stacks::RemoveCommand

  def execute

  end
end
