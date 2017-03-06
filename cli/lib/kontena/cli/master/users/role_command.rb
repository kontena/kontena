module Kontena::Cli::Master::Users


  class RoleCommand < Kontena::Command
    subcommand "add", "Add role to user", load_subcommand('roles/add_command')
    subcommand ["remove", "rm"], "Remove role from user", load_subcommand('roles/remove_command')
  end
end