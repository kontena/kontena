require_relative 'external_registries/add_command'
require_relative 'external_registries/list_command'
require_relative 'external_registries/delete_command'
require_relative 'external_registries/remove_command'

class Kontena::Cli::ExternalRegistryCommand < Kontena::Command

  subcommand "add", "Add external Docker image registry", Kontena::Cli::ExternalRegistries::AddCommand
  subcommand ["list", "ls"], "List external Docker image registries", Kontena::Cli::ExternalRegistries::ListCommand
  subcommand ["remove", "rm"], "Remove external Docker image registry", Kontena::Cli::ExternalRegistries::RemoveCommand
  subcommand "delete", "[DEPRECATED] Delete external Docker image registry", Kontena::Cli::ExternalRegistries::DeleteCommand

  def execute
  end
end
