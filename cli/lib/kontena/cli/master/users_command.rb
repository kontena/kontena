module Kontena::Cli::Master

  require_relative 'users/add_role_command'
  require_relative 'users/invite_command'
  require_relative 'users/list_command'
  require_relative 'users/remove_role_command'

  class UsersCommand < Clamp::Command
    subcommand "invite", "Invite user to Kontena Master", Users::InviteCommand
    subcommand ["list", "ls"], "List users", Users::ListCommand
    subcommand "add-role", "Add role to user", Users::AddRoleCommand
    subcommand "remove-role", "Remove role from user", Users::RemoveRoleCommand
  end
end
