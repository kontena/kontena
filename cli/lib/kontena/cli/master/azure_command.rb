
module Kontena::Cli::Master

  require_relative 'azure/create_command'

  class AzureCommand < Clamp::Command

    subcommand "create", "Create a new Azure master", Azure::CreateCommand

    def execute
    end
  end
end
