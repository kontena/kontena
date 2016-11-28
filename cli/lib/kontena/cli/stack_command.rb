require_relative 'stacks/install_command'
require_relative 'stacks/remove_command'
require_relative 'stacks/deploy_command'
require_relative 'stacks/upgrade_command'
require_relative 'stacks/list_command'
require_relative 'stacks/show_command'
require_relative 'stacks/build_command'
require_relative 'stacks/monitor_command'
require_relative 'stacks/logs_command'
require_relative 'stacks/push_command'
require_relative 'stacks/pull_command'
require_relative 'stacks/search_command'
require_relative 'stacks/install_command'
require_relative 'stacks/info_command'

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
  subcommand "push", "Push (or delete) a stack into the stacks registry", Kontena::Cli::Stacks::PushCommand
  subcommand "pull", "Pull a stack from the stacks registry", Kontena::Cli::Stacks::PullCommand
  subcommand "search", "Search for stacks in the stacks registry", Kontena::Cli::Stacks::SearchCommand
  subcommand "info", "Show info about a stack in the stacks registry", Kontena::Cli::Stacks::InfoCommand
  
  def execute
  end
end
