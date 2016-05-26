module Kontena::Cli::Nodes::Packet
  class RestartCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "NAME", "Node name"
    option "--token", "TOKEN", "Packet API token", required: true
    option "--project", "PROJECT ID", "Packet project id", required: true

    def execute
      require 'kontena/machine/packet'

      restarter = Kontena::Machine::Packet::NodeRestarter.new(token)
      restarter.run!(project, name)
    end
  end
end
