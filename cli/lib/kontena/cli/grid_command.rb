require_relative 'grids/list_command'
require_relative 'grids/create_command'
require_relative 'grids/use_command'
require_relative 'grids/show_command'
require_relative 'grids/remove_command'
require_relative 'grids/current_command'
require_relative 'grids/audit_log_command'
require_relative 'grids/list_users_command'
require_relative 'grids/add_user_command'
require_relative 'grids/remove_user_command'

class Kontena::Cli::GridCommand < Clamp::Command

  subcommand "list", "List all grids", Kontena::Cli::Grids::ListCommand
  subcommand "create", "Create a new grid", Kontena::Cli::Grids::CreateCommand
  subcommand "use", "Switch to use specific grid", Kontena::Cli::Grids::UseCommand
  subcommand "show", "Show grid details", Kontena::Cli::Grids::ShowCommand
  subcommand "remove", "Remove a grid", Kontena::Cli::Grids::RemoveCommand
  subcommand "current", "Show current grid details", Kontena::Cli::Grids::CurrentCommand
  subcommand "audit-log", "Show audit log of the current grid", Kontena::Cli::Grids::AuditLogCommand
  subcommand "list-users", "List current grid users", Kontena::Cli::Grids::ListUsersCommand
  subcommand "add-user", "Add user to the current grid", Kontena::Cli::Grids::AddUserCommand
  subcommand "remove-user", "Remove user from the current grid", Kontena::Cli::Grids::RemoveUserCommand

  def execute
  end
end
