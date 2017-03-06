class Kontena::Cli::VaultCommand < Kontena::Command

  subcommand ["list", "ls"], "List secrets", load_subcommand('vault/list_command')
  subcommand "write", "Write a secret", load_subcommand('vault/write_command')
  subcommand "read", "Read secret", load_subcommand('vault/read_command')
  subcommand "update", "Update secret", load_subcommand('vault/update_command')
  subcommand ["remove", "rm"], "Remove secret", load_subcommand('vault/remove_command')
  subcommand "export", "Export secrets to STDOUT", load_subcommand('vault/export_command')
  subcommand "import", "Import secrets from a file or STDIN", load_subcommand('vault/import_command')

  def execute
  end
end
