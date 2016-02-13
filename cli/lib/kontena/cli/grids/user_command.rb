require_relative 'users/list_command'
require_relative 'users/add_command'
require_relative 'users/remove_command'

class Kontena::Cli::Grids::UserCommand < Clamp::Command

  subcommand ["list","ls"], "List current grid users", Kontena::Cli::Grids::Users::ListCommand
  subcommand "add", "Add user to the current grid", Kontena::Cli::Grids::Users::AddCommand
  subcommand ["remove", "rm"], "Remove user from the current grid", Kontena::Cli::Grids::Users::RemoveCommand

  def execute
  end
end
