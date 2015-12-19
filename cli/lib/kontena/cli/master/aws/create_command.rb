require 'securerandom'

module Kontena::Cli::Master::Aws
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--access-key", "ACCESS_KEY", "AWS access key ID", required: true
    option "--secret-key", "SECRET_KEY", "AWS secret key", required: true
    option "--key-pair", "KEY_PAIR", "EC2 Key Pair", required: true
    option "--ssl-cert", "SSL CERT", "SSL certificate file"
    option "--region", "REGION", "EC2 Region", default: 'eu-west-1'
    option "--zone", "ZONE", "EC2 Availability Zone", default: 'a'
    option "--vpc-id", "VPC ID", "Virtual Private Cloud (VPC) ID"
    option "--subnet-id", "SUBNET ID", "VPC option to specify subnet to launch instance into"
    option "--type", "SIZE", "Instance type", default: 't2.small'
    option "--storage", "STORAGE", "Storage size (GiB)", default: '30'
    option "--vault-secret", "VAULT_SECRET", "Secret key for Vault"
    option "--vault-iv", "VAULT_IV", "Initialization vector for Vault"
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'
    option "--auth-provider-url", "AUTH_PROVIDER_URL", "Define authentication provider url"

    def execute
      require 'kontena/machine/aws'

      provisioner = Kontena::Machine::Aws::MasterProvisioner.new(access_key, secret_key, region)
      provisioner.run!(
          type: type,
          vpc: vpc_id,
          zone: zone,
          subnet: subnet_id,
          ssl_cert: ssl_cert,
          storage: storage,
          version: version,
          key_pair: key_pair,
          auth_server: auth_provider_url,
          vault_secret: vault_secret || SecureRandom.hex(24),
          vault_iv: vault_iv || SecureRandom.hex(24)
      )
    end
  end
end
