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

  subcommand "install", "Install a stack", Kontena::Cli::Stacks::InstallCommand
  subcommand "build", "Build stack file images", Kontena::Cli::Stacks::BuildCommand
  subcommand ["ls", "list"], "List stacks", Kontena::Cli::Stacks::ListCommand
  subcommand "show", "Show stack details", Kontena::Cli::Stacks::ShowCommand
  subcommand "upgrade", "Upgrade installed stack", Kontena::Cli::Stacks::UpgradeCommand
  subcommand "deploy", "Deploy stack", Kontena::Cli::Stacks::DeployCommand
  subcommand "logs", "Show logs from stack services", Kontena::Cli::Stacks::LogsCommand
  subcommand "monitor", "Monitor stack services", Kontena::Cli::Stacks::MonitorCommand
  subcommand ["remove","rm"], "Remove a deployed stack", Kontena::Cli::Stacks::RemoveCommand
  subcommand "push", "Push (or delete) a stack into the stacks registry", Kontena::Cli::Stacks::PushCommand
  subcommand "pull", "Pull a stack from the stacks registry", Kontena::Cli::Stacks::PullCommand
  subcommand "search", "Search for stacks in the stacks registry", Kontena::Cli::Stacks::SearchCommand
  subcommand "info", "Show info about a stack in the stacks registry", Kontena::Cli::Stacks::InfoCommand
  
  def execute
  end
end
