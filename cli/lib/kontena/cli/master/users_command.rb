module Kontena::Cli::Master

  require_relative 'users/invite_command'
  require_relative 'users/remove_command'
  require_relative 'users/list_command'
  require_relative 'users/role_command'

  class UsersCommand < Kontena::Command
    subcommand "invite", "Invite user to Kontena Master", Users::InviteCommand
    subcommand ["remove", "rm"], "Remove user from Kontena Master", Users::RemoveCommand
    subcommand ["list", "ls"], "List users", Users::ListCommand
    subcommand "role", "User role specific commands", Users::RoleCommand
  end
end
