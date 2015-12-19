require 'securerandom'

module Kontena::Cli::Master::Vagrant
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--memory", "MEMORY", "How much memory node has", default: '512'
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'
    option "--auth-provider-url", "AUTH_PROVIDER_URL", "Define authentication provider url"
    option "--vault-secret", "VAULT_SECRET", "Secret key for Vault"
    option "--vault-iv", "VAULT_IV", "Initialization vector for Vault"

    def execute
      require 'kontena/machine/vagrant'
      provisioner = Kontena::Machine::Vagrant::MasterProvisioner.new
      provisioner.run!(
        memory: memory,
        version: version,
        auth_server: auth_provider_url,
        vault_secret: vault_secret || SecureRandom.hex(24),
        vault_iv: vault_iv || SecureRandom.hex(24)
      )
    end
  end
end
