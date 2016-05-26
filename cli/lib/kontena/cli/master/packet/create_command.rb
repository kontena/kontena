require 'securerandom'

module Kontena::Cli::Master::Packet
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--token", "TOKEN", "Packet API token", required: true
    option "--project", "PROJECT ID", "Packet project id", required: true
    option "--ssl-cert", "PATH", "SSL certificate file (optional)"
    option "--type", "TYPE", "Server type (baremetal_0, baremetal_1, ..)", default: 'baremetal_0', attribute_name: :plan
    option "--facility", "FACILITY CODE", "Facility", default: 'ams1'
    option "--billing", "BILLING", "Billing cycle", default: 'hourly'
    option "--ssh-key", "PATH", "Path to ssh public key (optional)"
    option "--vault-secret", "VAULT_SECRET", "Secret key for Vault (optional)"
    option "--vault-iv", "VAULT_IV", "Initialization vector for Vault (optional)"
    option "--mongodb-uri", "URI", "External MongoDB uri (optional)"
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'
    option "--auth-provider-url", "AUTH_PROVIDER_URL", "Define authentication provider url"

    def execute

      require 'kontena/machine/packet'

      provisioner = Kontena::Machine::Packet::MasterProvisioner.new(token)
      provisioner.run!(
          project: project,
          billing: billing,
          ssh_key: ssh_key,
          ssl_cert: ssl_cert,
          plan: plan,
          facility: facility,
          version: version,
          auth_server: auth_provider_url,
          vault_secret: vault_secret || SecureRandom.hex(24),
          vault_iv: vault_iv || SecureRandom.hex(24),
          mongodb_uri: mongodb_uri
      )
    end

  end
end

