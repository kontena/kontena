require_relative 'registry/create_command'
require_relative 'registry/delete_command'

class Kontena::Cli::RegistryCommand < Clamp::Command

  subcommand "create", "Create Docker image registry service", Kontena::Cli::Registry::CreateCommand
  subcommand "delete", "Delete Docker image registry service", Kontena::Cli::Registry::DeleteCommand

  def execute
  end
end
