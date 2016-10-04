require_relative 'master/use_command'
require_relative 'master/list_command'
require_relative 'master/users_command'
require_relative 'master/current_command'

class Kontena::Cli::MasterCommand < Kontena::Command

  subcommand ["list", "ls"], "List masters where client has logged in", Kontena::Cli::Master::ListCommand
  subcommand "use", "Switch to use selected master", Kontena::Cli::Master::UseCommand
  subcommand "users", "Users specific commands", Kontena::Cli::Master::UsersCommand
  subcommand "current", "Show current master details", Kontena::Cli::Master::CurrentCommand

  def execute
  end
end
