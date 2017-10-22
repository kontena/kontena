module Kontena::Cli::Grids
  class UserCommand < Kontena::Command
    subcommand ["list", "ls"], "List grid users", load_subcommand('grids/users/list_command')
    subcommand "add", "Add user to grid", load_subcommand('grids/users/add_command')
    subcommand ["remove", "rm"], "Remove user from grid", load_subcommand('grids/users/remove_command')
  end
end
