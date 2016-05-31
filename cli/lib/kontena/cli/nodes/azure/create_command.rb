module Kontena::Cli::Nodes::Azure
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    option "--subscription-id", "SUBSCRIPTION ID", "Azure subscription id", required: true
    option "--subscription-cert", "CERTIFICATE", "Path to Azure management certificate", attribute_name: :certificate, required: true
    option "--size", "SIZE", "SIZE", default: 'Small'
    option "--network", "NETWORK", "Virtual Network name"
    option "--subnet", "SUBNET", "Subnet name"
    option "--ssh-key", "SSH KEY", "SSH private key file", required: true
    option "--location", "LOCATION", "Location", default: 'West Europe'
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'

    parameter "[NAME]", "Node name"

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/azure'
      grid = client(require_token).get("grids/#{current_grid}")
      provisioner = Kontena::Machine::Azure::NodeProvisioner.new(client(require_token), subscription_id, certificate)
      provisioner.run!(
        master_uri: api_url,
        grid_token: grid['token'],
        grid: current_grid,
        ssh_key: ssh_key,
        name: name,
        size: size,
        virtual_network: network,
        subnet: subnet,
        location: location,
        version: version
      )
    end
  end
end
