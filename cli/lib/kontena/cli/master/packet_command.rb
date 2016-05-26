
module Kontena::Cli::Master

  require_relative 'packet/create_command'

  class PacketCommand < Clamp::Command

    subcommand "create", "Create a new Packet master", Packet::CreateCommand

    def execute
    end
  end
end

