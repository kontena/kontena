class Kontena::Cli::MasterCommand < Kontena::Command
  include Kontena::Util

  subcommand ["list", "ls"], "List masters where client has logged in", load_subcommand('master/list_command')
  subcommand ["remove", "rm"], "Remove a master from configuration", load_subcommand('master/remove_command')
  subcommand ["config", "cfg"], "Configure master settings", load_subcommand('master/config_command')
  subcommand "use", "Switch to use selected master", load_subcommand('master/use_command')
  subcommand "users", "Users specific commands", load_subcommand('master/users_command')
  subcommand "current", "Show current master details", load_subcommand('master/current_command')
  subcommand "login", "Authenticate to Kontena Master", load_subcommand('master/login_command')
  subcommand "logout", "Log out of Kontena Master", load_subcommand('master/logout_command')
  subcommand "token", "Manage Kontena Master access tokens", load_subcommand('master/token_command')
  subcommand "join", "Join Kontena Master using an invitation code", load_subcommand('master/join_command')
  subcommand "audit-log", "Show master audit logs", load_subcommand('master/audit_log_command')
  subcommand "create", "Install a new Kontena Master", load_subcommand('master/create_command') if experimental?
  subcommand "init-cloud", "Configure current master to use Kontena Cloud services", load_subcommand('master/init_cloud_command')
  subcommand "ssh", "Connect to the master via SSH", load_subcommand('master/ssh_command')

  def execute
  end
end
