require_relative 'stacks/install_command'
require_relative 'stacks/remove_command'
require_relative 'stacks/deploy_command'
require_relative 'stacks/upgrade_command'
require_relative 'stacks/list_command'
require_relative 'stacks/show_command'
require_relative 'stacks/build_command'
require_relative 'stacks/monitor_command'
require_relative 'stacks/logs_command'

class Kontena::Cli::StackCommand < Kontena::Command

  subcommand "install", "Install a stack", Kontena::Cli::Stacks::InstallCommand
  subcommand "build", "Build stack file images", Kontena::Cli::Stacks::BuildCommand
  subcommand ["ls", "list"], "List stacks", Kontena::Cli::Stacks::ListCommand
  subcommand "show", "Show stack details", Kontena::Cli::Stacks::ShowCommand
  subcommand "upgrade", "Upgrade installed stack", Kontena::Cli::Stacks::UpgradeCommand
  subcommand "deploy", "Deploy stack", Kontena::Cli::Stacks::DeployCommand
  subcommand "logs", "Show stack logs from stack services", Kontena::Cli::Stacks::LogsCommand
  subcommand "monitor", "Monitor stack", Kontena::Cli::Stacks::MonitorCommand
  subcommand ["remove","rm"], "Remove stack", Kontena::Cli::Stacks::RemoveCommand

  def execute

  end
end
