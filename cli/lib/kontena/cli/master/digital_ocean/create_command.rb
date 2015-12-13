require 'securerandom'

module Kontena::Cli::Master::DigitalOcean
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--token", "TOKEN", "DigitalOcean API token", required: true
    option "--ssh-key", "SSH_KEY", "Path to ssh public key", required: true
    option "--ssl-cert", "SSL CERT", "SSL certificate file"
    option "--size", "SIZE", "Droplet size", default: '1gb'
    option "--region", "REGION", "Region", default: 'ams2'
    option "--vault-secret", "VAULT_SECRET", "Secret key for Vault"
    option "--vault-iv", "VAULT_IV", "Initialization vector for Vault"
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'
    option "--auth-provider-url", "AUTH_PROVIDER_URL", "Define authentication provider url"


    def execute

      require 'kontena/machine/digital_ocean'

      provisioner = Kontena::Machine::DigitalOcean::MasterProvisioner.new(token)
      provisioner.run!(
          ssh_key: ssh_key,
          ssl_cert: ssl_cert,
          size: size,
          region: region,
          version: version,
          auth_server: auth_provider_url,
          vault_secret: vault_secret || SecureRandom.hex(24),
          vault_iv: vault_iv || SecureRandom.hex(24)
      )
    end

  end
end
