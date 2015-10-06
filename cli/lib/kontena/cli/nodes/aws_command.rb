require_relative 'aws/create_command'
require_relative 'aws/terminate_command'
require_relative 'aws/restart_command'

module Kontena::Cli::Nodes
  class AwsCommand < Clamp::Command

    subcommand "create", "Create a new AWS node", Aws::CreateCommand
    subcommand "terminate", "Terminate AWS node", Aws::TerminateCommand
    subcommand "restart", "Restart AWS node", Aws::RestartCommand

    def execute
    end
  end
end
