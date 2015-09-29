require_relative 'apps/init_command'
require_relative 'apps/build_command'
require_relative 'apps/deploy_command'
require_relative 'apps/start_command'
require_relative 'apps/stop_command'
require_relative 'apps/remove_command'
require_relative 'apps/list_command'
require_relative 'apps/logs_command'

class Kontena::Cli::AppCommand < Clamp::Command

  subcommand "init", "Init Kontena application", Kontena::Cli::Apps::InitCommand
  subcommand "build", "Build Kontena services", Kontena::Cli::Apps::BuildCommand
  subcommand "deploy", "Deploy Kontena services", Kontena::Cli::Apps::DeployCommand
  subcommand "start", "Start services", Kontena::Cli::Apps::StartCommand
  subcommand "stop", "Stop services", Kontena::Cli::Apps::StopCommand
  subcommand ["remove","rm"], "Remove services", Kontena::Cli::Apps::RemoveCommand
  subcommand ["ps", "list"], "List services", Kontena::Cli::Apps::ListCommand
  subcommand ["logs"], "Show service logs", Kontena::Cli::Apps::LogsCommand
  def execute
  end
end