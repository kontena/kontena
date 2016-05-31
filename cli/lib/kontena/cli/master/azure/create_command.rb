require 'securerandom'

module Kontena::Cli::Master::Azure
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--subscription-id", "SUBSCRIPTION ID", "Azure subscription id", required: true
    option "--subscription-cert", "CERTIFICATE", "Path to Azure management certificate", attribute_name: :certificate, required: true
    option "--size", "SIZE", "SIZE", default: 'Small'
    option "--network", "NETWORK", "Virtual Network name"
    option "--subnet", "SUBNET", "Subnet name"
    option "--ssh-key", "SSH KEY", "SSH private key file", required: true
    option "--location", "LOCATION", "Location", default: 'West Europe'
    option "--ssl-cert", "SSL CERT", "SSL certificate file"
    option "--vault-secret", "VAULT_SECRET", "Secret key for Vault"
    option "--vault-iv", "VAULT_IV", "Initialization vector for Vault"
    option "--auth-provider-url", "AUTH_PROVIDER_URL", "Define authentication provider url"
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'

    def execute
      require 'kontena/machine/azure'
      provisioner = Kontena::Machine::Azure::MasterProvisioner.new(subscription_id, certificate)
      provisioner.run!(
          ssh_key: ssh_key,
          ssl_cert: ssl_cert,
          size: size,
          virtual_network: network,
          subnet: subnet,
          location: location,
          auth_server: auth_provider_url,
          version: version,
          vault_secret: vault_secret || SecureRandom.hex(24),
          vault_iv: vault_iv || SecureRandom.hex(24)
      )
    end
  end
end
