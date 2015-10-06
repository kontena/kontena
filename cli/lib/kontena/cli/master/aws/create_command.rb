module Kontena::Cli::Master::Aws
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--access-key", "ACCESS_KEY", "AWS access key ID", required: true
    option "--secret-key", "SECRET_KEY", "AWS secret key", required: true
    option "--region", "REGION", "EC2 Region", default: 'eu-west-1'
    option "--zone", "ZONE", "EC2 Availability Zone", default: 'a'
    option "--vpc-id", "VPC ID", "Virtual Private Cloud (VPC) ID"
    option "--subnet-id", "SUBNET ID", "VPC option to specify subnet to launch instance into"
    option "--key-pair", "KEY_PAIR", "EC2 Key Pair", required: true
    option "--type", "SIZE", "Instance type", default: 't2.small'
    option "--storage", "STORAGE", "Storage size (GiB)", default: '30'
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
          storage: storage,
          version: version,
          key_pair: key_pair,
          auth_server: auth_provider_url
      )
    end
  end
end