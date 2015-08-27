require_relative 'digital_ocean/create_command'
require_relative 'digital_ocean/terminate_command'

module Kontena::Cli::Nodes
  class DigitalOceanCommand < Clamp::Command

    subcommand "create", "Create a new DigitalOcean node", DigitalOcean::CreateCommand
    subcommand "terminate", "Terminate DigitalOcean node", DigitalOcean::TerminateCommand

    def execute
    end
  end
end
