require_relative 'services/list_command'
require_relative 'services/show_command'
require_relative 'services/update_command'
require_relative 'services/deploy_command'
require_relative 'services/stop_command'
require_relative 'services/start_command'
require_relative 'services/restart_command'
require_relative 'services/create_command'
require_relative 'services/scale_command'
require_relative 'services/delete_command'
require_relative 'services/containers_command'
require_relative 'services/logs_command'
require_relative 'services/stats_command'

class Kontena::Cli::ServiceCommand < Clamp::Command

  subcommand "list", "List services", Kontena::Cli::Services::ListCommand
  subcommand "create", "Create a new service", Kontena::Cli::Services::CreateCommand
  subcommand "show", "Show service details", Kontena::Cli::Services::ShowCommand
  subcommand "update", "Update service configuration", Kontena::Cli::Services::UpdateCommand
  subcommand "deploy", "Deploy service", Kontena::Cli::Services::DeployCommand
  subcommand "stop", "Stop service", Kontena::Cli::Services::StopCommand
  subcommand "start", "Start service", Kontena::Cli::Services::StartCommand
  subcommand "restart", "Restart service", Kontena::Cli::Services::RestartCommand
  subcommand "scale", "Scale service", Kontena::Cli::Services::ScaleCommand
  subcommand "delete", "Delete service", Kontena::Cli::Services::DeleteCommand
  subcommand "containers", "List service containers", Kontena::Cli::Services::ContainersCommand
  subcommand "logs", "Show service logs", Kontena::Cli::Services::LogsCommand
  subcommand "stats", "Show service statistics", Kontena::Cli::Services::StatsCommand

  def execute
  end
end
