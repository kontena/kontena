require_relative 'cloud/login_command'
require_relative 'cloud/logout_command'
require_relative 'cloud/master_command'

class Kontena::Cli::CloudCommand < Kontena::Command
  subcommand "login", "Authenticate to Kontena Cloud", Kontena::Cli::Cloud::LoginCommand
  subcommand "logout", "Logout from Kontena Cloud", Kontena::Cli::Cloud::LogoutCommand
  subcommand "master", "Master specific commands", Kontena::Cli::Cloud::MasterCommand

  def execute
  end
end
