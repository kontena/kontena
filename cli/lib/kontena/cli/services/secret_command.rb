module Kontena::Cli::Services

  require_relative 'secrets/link_command'
  require_relative 'secrets/unlink_command'

  class SecretCommand < Kontena::Command
    subcommand "link", "Link secret from Vault", Secrets::LinkCommand
    subcommand "unlink", "Unlink secret from Vault", Secrets::UnlinkCommand
  end
end
