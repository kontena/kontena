module Kontena::Cli::Master

  require_relative 'aws/create_command'

  class AwsCommand < Clamp::Command
    subcommand "create", "Create a new AWS master", Aws::CreateCommand
  end
end
