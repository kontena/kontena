module Kontena::Cli::Master::User
  class RoleCommand < Kontena::Command
    subcommand "add", "Add role to user", load_subcommand('master/user/role/add_command')
    subcommand ["remove", "rm"], "Remove role from user", load_subcommand('master/user/role/remove_command')
  end
end
