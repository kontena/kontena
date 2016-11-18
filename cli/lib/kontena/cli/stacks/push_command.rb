require_relative 'common'

module Kontena::Cli::Stacks
  class PushCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "FILENAME", "Stack file path"

    requires_current_account_token

    def execute
      content = File.read(self.filename)
      yaml = YAML.load(content)
      stacks_client.push(yaml['stack'], yaml['version'], content)
    end
  end
end
