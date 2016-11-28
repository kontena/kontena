require_relative 'stacks/install_command'
require_relative 'stacks/remove_command'
require_relative 'stacks/deploy_command'
require_relative 'stacks/upgrade_command'
require_relative 'stacks/list_command'
require_relative 'stacks/show_command'
require_relative 'stacks/build_command'
require_relative 'stacks/monitor_command'
require_relative 'stacks/logs_command'
require_relative 'stacks/registry_command'

class Kontena::Cli::StackCommand < Kontena::Command

  subcommand "install", "Install a stack to a grid", Kontena::Cli::Stacks::InstallCommand
  subcommand ["ls", "list"], "List installed stacks in a grid", Kontena::Cli::Stacks::ListCommand
  subcommand ["remove","rm"], "Remove a deployed stack from a grid", Kontena::Cli::Stacks::RemoveCommand
  subcommand "show", "Show details about a stack in a grid", Kontena::Cli::Stacks::ShowCommand
  subcommand "upgrade", "Upgrade a stack in a grid", Kontena::Cli::Stacks::UpgradeCommand
  subcommand ["start", "deploy"], "Deploy an installed stack in a grid", Kontena::Cli::Stacks::DeployCommand
  subcommand "logs", "Show logs from services in a stack", Kontena::Cli::Stacks::LogsCommand
  subcommand "monitor", "Monitor services in a stack", Kontena::Cli::Stacks::MonitorCommand
  subcommand "build", "Build images listed in a stack file and push them to an image registry", Kontena::Cli::Stacks::BuildCommand
  subcommand "registry", "Stack registry related commands", Kontena::Cli::Stacks::RegistryCommand

  def execute
  end
end
