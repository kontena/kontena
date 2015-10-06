
module Kontena::Cli::Master

  require_relative 'digital_ocean/create_command'

  class DigitalOceanCommand < Clamp::Command

    subcommand "create", "Create a new DigitalOcean master", DigitalOcean::CreateCommand

    def execute
    end
  end
end
