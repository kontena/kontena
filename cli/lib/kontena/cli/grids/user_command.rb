module Kontena::Cli::Grids

  require_relative 'users/list_command'
  require_relative 'users/add_command'
  require_relative 'users/remove_command'

  class UserCommand < Kontena::Command
    subcommand ["list", "ls"], "List grid users", Users::ListCommand
    subcommand "add", "Add user to grid", Users::AddCommand
    subcommand ["remove", "rm"], "Remove user from grid", Users::RemoveCommand
  end
end
