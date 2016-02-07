module Kontena::Cli::Nodes::Azure
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--subscription-id", "SUBSCRIPTION ID", "Azure subscription id", required: true
    option "--subscription-cert", "CERTIFICATE", "Path to Azure management certificate", attribute_name: :certificate, required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/azure'

      grid = client(require_token).get("grids/#{current_grid}")
      destroyer = Kontena::Machine::Azure::NodeDestroyer.new(client(require_token), subscription_id, certificate)
      destroyer.run!(grid, name)
    end
  end
end
