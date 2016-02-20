module Kontena::Cli::Nodes::Vagrant
  class TerminateCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"

    def execute
      require_api_url
      require_current_grid

      require 'kontena/machine/vagrant'
      destroyer = Kontena::Machine::Vagrant::NodeDestroyer.new(client(require_token))
      destroyer.run!(current_grid, name)
    end
  end
end
