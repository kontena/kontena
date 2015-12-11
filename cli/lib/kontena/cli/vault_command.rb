require_relative 'vault/write_command'
require_relative 'vault/list_command'
require_relative 'vault/read_command'
require_relative 'vault/remove_command'

class Kontena::Cli::VaultCommand < Clamp::Command

  subcommand "write", "Write a secret", Kontena::Cli::Vault::WriteCommand
  subcommand ["list", "ls"], "List secrets", Kontena::Cli::Vault::ListCommand
  subcommand "read", "Read secret", Kontena::Cli::Vault::ReadCommand
  subcommand ["remove", "rm"], "Remove secret", Kontena::Cli::Vault::RemoveCommand

  def execute
  end
end
