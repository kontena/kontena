module Kontena::Cli::Services


  class SecretCommand < Kontena::Command
    subcommand "link", "Link secret from Vault", load_subcommand('secrets/link_command')
    subcommand "unlink", "Unlink secret from Vault", load_subcommand('secrets/unlink_command')
  end
end