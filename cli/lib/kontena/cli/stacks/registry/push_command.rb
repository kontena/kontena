require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class PushCommand < Kontena::Command
    include Kontena::Cli::Stacks::Common

    banner "Pushes (uploads) a stack to the stack registry"

    parameter "FILENAME", "Stack file path"

    requires_current_account_token

    def execute
      file = Kontena::Cli::Stacks::YAML::Reader.new(
        filename,
        skip_variables: true,
        skip_validation: true
      )
      name = "#{file.stack_name}:#{file.stack_version}"
      spinner("Pushing #{pastel.cyan(name)} to stacks registry") do
        stacks_client.push(file.stack_name, file.stack_version, file.raw_content)
      end
    end
  end
end
