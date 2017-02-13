require_relative 'volumes/create_command'
require_relative 'volumes/remove_command'
require_relative 'volumes/list_command'

class Kontena::Cli::VolumeCommand < Kontena::Command

  subcommand "create", "Create a managed volume", Kontena::Cli::Volume::CreateCommand
  subcommand ["remove", "rm"], "Remove a managed volume", Kontena::Cli::Volume::RemoveCommand
  subcommand ["list", "ls"], "List managed volumes", Kontena::Cli::Volume::ListCommand

end
