module Kontena::Cli::Nodes::Packet
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--token", "TOKEN", "Packet API token", required: true
    option "--project", "PROJECT ID", "Packet project id", required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/packet'
      grid = client(require_token).get("grids/#{current_grid}")
      destroyer = Kontena::Machine::Packet::NodeDestroyer.new(client(require_token), token)
      destroyer.run!(grid, project, name)
    end
  end
end
