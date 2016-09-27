require_relative '../main_command'
require_relative 'master/use_command'
require_relative 'master/list_command'
require_relative 'master/users_command'
require_relative 'master/current_command'
require_relative 'master/config_command'
require_relative 'master/login_command'
require_relative 'master/join_command'
require_relative 'master/audit_log_command'

if ENV["DEV"]
  begin
    require_relative 'master/create_command'
  rescue LoadError
  end
end

class Kontena::Cli::MasterCommand < Kontena::Command
  subcommand ["list", "ls"], "List masters where client has logged in", Kontena::Cli::Master::ListCommand
  subcommand ["config", "cfg"], "Configure master settings", Kontena::Cli::Master::ConfigCommand
  subcommand "use", "Switch to use selected master", Kontena::Cli::Master::UseCommand
  subcommand "users", "Users specific commands", Kontena::Cli::Master::UsersCommand
  subcommand "current", "Show current master details", Kontena::Cli::Master::CurrentCommand
  subcommand "login", "Authenticate to Kontena Master", Kontena::Cli::Master::LoginCommand
  subcommand "join", "Join Kontena Master using an invitation code", Kontena::Cli::Master::JoinCommand
  subcommand "audit-log", "Show master audit logs", Kontena::Cli::Master::AuditLogCommand

  if ENV["DEV"]
    subcommand "create", "Install a new Kontena Master", Kontena::Cli::Master::CreateCommand
  end

  def execute
  end
end
