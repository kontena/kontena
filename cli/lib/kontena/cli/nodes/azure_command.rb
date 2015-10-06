require_relative 'azure/create_command'
require_relative 'azure/restart_command'
require_relative 'azure/terminate_command'

module Kontena::Cli::Nodes
  class AzureCommand < Clamp::Command

    subcommand "create", "Create a new Azure node", Azure::CreateCommand
    subcommand "restart", "Restart Azure node", Azure::RestartCommand
    subcommand "terminate", "Terminate Azure node", Azure::TerminateCommand

    def execute
    end
  end
end
