module Kontena::Cli::Nodes::Upcloud
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--username", "USER", "Upcloud username", required: true
    option "--password", "PASS", "Upcloud password", required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/upcloud'
      grid = client(require_token).get("grids/#{current_grid}")
      destroyer = Kontena::Machine::Upcloud::NodeDestroyer.new(client(require_token), username, password)
      destroyer.run!(grid, name)
    end
  end
end
