module Kontena::Cli::Nodes::Packet
  class CreateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "[NAME]", "Node name"
    option "--token", "TOKEN", "Packet API token", required: true
    option "--project", "PROJECT ID", "Packet project id", required: true
    option "--type", "TYPE", "Server type (baremetal_0, baremetal_1, ..)", default: 'baremetal_0', attribute_name: :plan
    option "--facility", "FACILITY CODE", "Facility", default: 'ams1'
    option "--billing", "BILLING", "Billing cycle", default: 'hourly'
    option "--ssh-key", "PATH", "Path to ssh public key (optional)"
    option "--version", "VERSION", "Define installed Kontena version", default: 'latest'

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/packet'
      grid = client(require_token).get("grids/#{current_grid}")
      provisioner = Kontena::Machine::Packet::NodeProvisioner.new(client(require_token), token)
      provisioner.run!(
        master_uri: api_url,
        grid_token: grid['token'],
        grid: current_grid,
        project: project,
        billing: billing,
        ssh_key: ssh_key,
        plan: plan,
        facility: facility,
        version: version
      )
    end
  end
end
