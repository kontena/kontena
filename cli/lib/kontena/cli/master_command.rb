require_relative '../main_command'
require_relative 'master/use_command'
require_relative 'master/remove_command'
require_relative 'master/list_command'
require_relative 'master/users_command'
require_relative 'master/current_command'
require_relative 'master/config_command'
require_relative 'master/login_command'
require_relative 'master/logout_command'
require_relative 'master/join_command'
require_relative 'master/audit_log_command'
require_relative 'master/token_command'
require_relative 'master/init_cloud_command'
require_relative 'master/ssh_command'

class Kontena::Cli::MasterCommand < Kontena::Command
  include Kontena::Util

  subcommand ["list", "ls"], "List masters where client has logged in", Kontena::Cli::Master::ListCommand
  subcommand ["remove", "rm"], "Remove a master from configuration file", Kontena::Cli::Master::RemoveCommand
  subcommand ["config", "cfg"], "Configure master settings", Kontena::Cli::Master::ConfigCommand
  subcommand "use", "Switch to use selected master", Kontena::Cli::Master::UseCommand
  subcommand "users", "Users specific commands", Kontena::Cli::Master::UsersCommand
  subcommand "current", "Show current master details", Kontena::Cli::Master::CurrentCommand
  subcommand "login", "Authenticate to Kontena Master", Kontena::Cli::Master::LoginCommand
  subcommand "logout", "Log out of Kontena Master", Kontena::Cli::Master::LogoutCommand
  subcommand "token", "Manage Kontena Master access tokens", Kontena::Cli::Master::TokenCommand
  subcommand "join", "Join Kontena Master using an invitation code", Kontena::Cli::Master::JoinCommand
  subcommand "audit-log", "Show master audit logs", Kontena::Cli::Master::AuditLogCommand
  subcommand "init-cloud", "Configure current master to use Kontena Cloud services", Kontena::Cli::Master::InitCloudCommand
  subcommand "ssh", "Connect to the master via SSH", Kontena::Cli::Master::SshCommand

  if experimental?
    require_relative 'master/create_command'
    subcommand "create", "Install a new Kontena Master", Kontena::Cli::Master::CreateCommand
  end

  def execute
  end
end
