require_relative 'vault/export_command'
require_relative 'vault/write_command'
require_relative 'vault/list_command'
require_relative 'vault/read_command'
require_relative 'vault/remove_command'
require_relative 'vault/update_command'

class Kontena::Cli::VaultCommand < Kontena::Command

  subcommand ["list", "ls"], "List secrets", Kontena::Cli::Vault::ListCommand
  subcommand "write", "Write a secret", Kontena::Cli::Vault::WriteCommand
  subcommand "read", "Read secret", Kontena::Cli::Vault::ReadCommand
  subcommand "update", "Update secret", Kontena::Cli::Vault::UpdateCommand
  subcommand ["remove", "rm"], "Remove secret", Kontena::Cli::Vault::RemoveCommand
  subcommand "export", "Export secrets to STDOUT in yaml format", Kontena::Cli::Vault::ExportCommand

  def execute
  end
end
