require_relative 'common'

module Kontena::Cli::Stacks
  class PushCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "FILENAME", "Stack file path"

    requires_current_account_token

    def execute
      file = YAML::Reader.new(self.filename, skip_variables: true, replace_missing: "filler")
      stacks_client.push(file.yaml['stack'], file.yaml['version'], file.raw_content)
    end
  end
end
