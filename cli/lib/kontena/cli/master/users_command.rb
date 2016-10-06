module Kontena::Cli::Master


  class UsersCommand < Kontena::Command
    subcommand "invite", "Invite user to Kontena Master", load_subcommand('users/invite_command')
    subcommand ["remove", "rm"], "Remove user from Kontena Master", load_subcommand('users/remove_command')
    subcommand ["list", "ls"], "List users", load_subcommand('users/list_command')
    subcommand "role", "User role specific commands", load_subcommand('users/role_command')
  end
end