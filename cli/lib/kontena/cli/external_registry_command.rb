require_relative 'external_registries/add_command'
require_relative 'external_registries/list_command'
require_relative 'external_registries/delete_command'


class Kontena::Cli::ExternalRegistryCommand < Clamp::Command

  subcommand "add", "Add external Docker image registry", Kontena::Cli::ExternalRegistries::AddCommand
  subcommand "list", "List external Docker image registries", Kontena::Cli::ExternalRegistries::ListCommand
  subcommand "delete", "Delete external Docker image registry", Kontena::Cli::ExternalRegistries::DeleteCommand

  def execute
  end
end
