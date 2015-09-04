module Kontena::Cli::Nodes::Aws
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--name", "NAME", "Node name"
    option "--access-key", "ACCESS_KEY", "AWS access key ID", required: true
    option "--secret-key", "SECRET_KEY", "AWS secret key", required: true
    option "--region", "REGION", "EC2 Region", default: 'eu-west-1'
    option "--key-pair", "KEY_PAIR", "EC2 Key Pair", required: true
    option "--type", "SIZE", "Instance type", default: 't2.small'
    option "--storage", "STORAGE", "Storage size (GiB)", default: '30'
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/aws'
      grid = client(require_token).get("grids/#{current_grid}")
      provisioner = Kontena::Machine::Aws::NodeProvisioner.new(client(require_token), access_key, secret_key, region)
      provisioner.run!(
          master_uri: api_url,
          grid_token: grid['token'],
          grid: current_grid,
          name: name,
          type: type,
          storage: storage,
          version: version,
          key_pair: key_pair
      )
    end
  end
end