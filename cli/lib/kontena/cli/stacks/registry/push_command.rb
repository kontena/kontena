require_relative '../common'

module Kontena::Cli::Stacks::Registry
  class PushCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Stacks::Common

    banner "Pushes (uploads) a stack to the stack registry"

    parameter "FILENAME", "Stack file path"

    requires_current_account_token

    def execute
      file = Kontena::Cli::Stacks::YAML::Reader.new(filename, skip_variables: true, replace_missing: "filler")
      file.execute
      name = "#{file.yaml['stack']}:#{file.yaml['version']}"
      spinner("Pushing #{pastel.cyan(name)} to stacks registry") do
        stacks_client.push(file.yaml['stack'], file.yaml['version'], file.raw_content)
      end
    end
  end
end
