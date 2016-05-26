require_relative 'packet/create_command'
require_relative 'packet/restart_command'
require_relative 'packet/terminate_command'

module Kontena::Cli::Nodes
  class PacketCommand < Clamp::Command

    subcommand "create", "Create a new Packet node", Packet::CreateCommand
    subcommand "restart", "Restart a Packet node", Packet::RestartCommand
    subcommand "terminate", "Terminate a Packet node", Packet::TerminateCommand

    def execute
    end
  end
end
