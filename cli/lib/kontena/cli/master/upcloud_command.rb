
module Kontena::Cli::Master

  require_relative 'upcloud/create_command'

  class UpcloudCommand < Clamp::Command

    subcommand "create", "Create a new Upcloud master", Upcloud::CreateCommand

    def execute
    end
  end
end
