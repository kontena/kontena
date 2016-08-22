require_relative 'apps/init_command'
require_relative 'apps/build_command'
require_relative 'apps/config_command'
require_relative 'apps/deploy_command'
require_relative 'apps/start_command'
require_relative 'apps/stop_command'
require_relative 'apps/restart_command'
require_relative 'apps/remove_command'
require_relative 'apps/list_command'
require_relative 'apps/logs_command'
require_relative 'apps/monitor_command'
require_relative 'apps/show_command'
require_relative 'apps/scale_command'

class Kontena::Cli::AppCommand < Kontena::Command

  subcommand "init", "Init Kontena application", Kontena::Cli::Apps::InitCommand
  subcommand "build", "Build Kontena services", Kontena::Cli::Apps::BuildCommand
  subcommand "config", "View service configurations", Kontena::Cli::Apps::ConfigCommand
  subcommand "deploy", "Deploy Kontena services", Kontena::Cli::Apps::DeployCommand
  subcommand "scale", "Scale services", Kontena::Cli::Apps::ScaleCommand
  subcommand "start", "Start services", Kontena::Cli::Apps::StartCommand
  subcommand "stop", "Stop services", Kontena::Cli::Apps::StopCommand
  subcommand "restart", "Restart services", Kontena::Cli::Apps::RestartCommand
  subcommand "show", "Show service details", Kontena::Cli::Apps::ShowCommand
  subcommand ["ps", "list", "ls"], "List services", Kontena::Cli::Apps::ListCommand
  subcommand ["logs"], "Show service logs", Kontena::Cli::Apps::LogsCommand
  subcommand "monitor", "Monitor services", Kontena::Cli::Apps::MonitorCommand
  subcommand ["remove","rm"], "Remove services", Kontena::Cli::Apps::RemoveCommand
  def execute
  end
end
