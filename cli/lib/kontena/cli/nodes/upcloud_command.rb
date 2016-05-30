require_relative 'upcloud/create_command'
require_relative 'upcloud/restart_command'
require_relative 'upcloud/terminate_command'

module Kontena::Cli::Nodes
  class UpcloudCommand < Clamp::Command

    subcommand "create", "Create a new Upcloud node", Upcloud::CreateCommand
    subcommand "restart", "Restart Upcloud node", Upcloud::RestartCommand
    subcommand "terminate", "Terminate Upcloud node", Upcloud::TerminateCommand

    def execute
    end
  end
end
