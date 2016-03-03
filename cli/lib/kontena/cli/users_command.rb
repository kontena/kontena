require_relative 'users/invite_command'
require_relative 'users/list_command'
require_relative 'users/add_role_command'
require_relative 'users/remove_role_command'

class Kontena::Cli::UsersCommand < Clamp::Command

  subcommand "invite", "Invite user to Kontena Master", Kontena::Cli::Users::InviteCommand
  subcommand ["list", "ls"], "List users", Kontena::Cli::Users::ListCommand
  subcommand "add-role", "Add role to user", Kontena::Cli::Users::AddRoleCommand
  subcommand "remove-role", "Remove role from user", Kontena::Cli::Users::RemoveRoleCommand

  def execute
  end
end