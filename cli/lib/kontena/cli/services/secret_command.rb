module Kontena::Cli::Services


  class SecretCommand < Kontena::Command
    subcommand "link", "Link secret from Vault", load_subcommand('services/secrets/link_command')
    subcommand "unlink", "Unlink secret from Vault", load_subcommand('services/secrets/unlink_command')
  end
end
