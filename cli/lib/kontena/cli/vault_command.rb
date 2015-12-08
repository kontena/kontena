require_relative 'vault/create_command'
require_relative 'vault/list_command'
require_relative 'vault/show_command'
require_relative 'vault/delete_command'

class Kontena::Cli::VaultCommand < Clamp::Command

  subcommand "create", "Create secret", Kontena::Cli::Vault::CreateCommand
  subcommand ["list", "ls"], "List secrets", Kontena::Cli::Vault::ListCommand
  subcommand "show", "Show secret", Kontena::Cli::Vault::ShowCommand
  subcommand ["remove", "rm"], "Remove secret", Kontena::Cli::Vault::RemoveCommand

  def execute
  end
end
