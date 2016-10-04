module Kontena::Cli::Master::Users

  require_relative 'roles/add_command'
  require_relative 'roles/remove_command'

  class RoleCommand < Kontena::Command
    subcommand "add", "Add role to user", Roles::AddCommand
    subcommand ["remove", "rm"], "Remove role from user", Roles::RemoveCommand
  end
end
