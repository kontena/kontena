require_relative 'apps/init_command'
require_relative 'apps/deploy_command'

class Kontena::Cli::AppCommand < Clamp::Command
  subcommand "init", "Init Kontena application", Kontena::Cli::Apps::InitCommand
  subcommand "deploy", "Deploy Kontena application", Kontena::Cli::Apps::DeployCommand

  def execute
  end
end