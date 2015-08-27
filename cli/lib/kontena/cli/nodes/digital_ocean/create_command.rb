module Kontena::Cli::Nodes::DigitalOcean
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common

    option "--name", "NAME", "Node name"
    option "--token", "TOKEN", "DigitalOcean API token", required: true
    option "--ssh-key", "SSH_KEY", "Path to ssh public key", required: true
    option "--size", "SIZE", "Droplet size (default: 1gb)", default: '1gb'
    option "--region", "REGION", "Region (default: ams2)", default: 'ams2'
    option "--version", "VERSION", "Define installed Kontena version (default: #{Kontena::Cli::VERSION})", default: Kontena::Cli::VERSION

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/digital_ocean'
      grid = client(require_token).get("grids/#{current_grid}")
      provisioner = Kontena::Machine::DigitalOcean::NodeProvisioner.new(client(require_token), token)
      provisioner.run!(
        master_uri: api_url,
        grid_token: grid['token'],
        grid: current_grid,
        ssh_key: ssh_key,
        name: name,
        size: size,
        region: region,
        version: version
      )
    end
  end
end
