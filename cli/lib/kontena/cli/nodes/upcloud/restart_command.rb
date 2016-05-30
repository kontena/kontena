module Kontena::Cli::Nodes::Upcloud
  class RestartCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--username", "USER", "Upcloud username", required: true
    option "--password", "PASS", "Upcloud password", required: true

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/upcloud'

      restarter = Kontena::Machine::Upcloud::NodeRestarter.new(username, password)
      restarter.run!(name)
    end
  end
end
