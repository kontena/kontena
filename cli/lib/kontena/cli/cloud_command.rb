require_relative 'cloud/login_command'
require_relative 'cloud/master_command'

class Kontena::Cli::CloudCommand < Kontena::Command
  subcommand "login", "Authenticate to Kontena Cloud", Kontena::Cli::Cloud::LoginCommand
  subcommand "master", "Master specific commands", Kontena::Cli::Cloud::MasterCommand

  def execute
  end
end
