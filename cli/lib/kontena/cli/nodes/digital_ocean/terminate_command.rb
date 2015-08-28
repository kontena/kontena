module Kontena::Cli::Nodes::DigitalOcean
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "NAME", "Node name"
    option "--token", "TOKEN", "DigitalOcean API token", required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/digital_ocean'
      grid = client(require_token).get("grids/#{current_grid}")
      destroyer = Kontena::Machine::DigitalOcean::NodeDestroyer.new(client(require_token), token)
      destroyer.run!(grid, name)
    end
  end
end
