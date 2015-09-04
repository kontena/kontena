require_relative 'aws/create_command'
require_relative 'aws/terminate_command'

module Kontena::Cli::Nodes
  class AwsCommand < Clamp::Command

    subcommand "create", "Create a new AWS node", Aws::CreateCommand
    subcommand "terminate", "Terminate AWS node", Aws::TerminateCommand

    def execute
    end
  end
end
