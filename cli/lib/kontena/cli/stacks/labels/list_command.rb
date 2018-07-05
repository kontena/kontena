require_relative '../common'
require_relative 'common'

module Kontena::Cli::Stacks::Labels
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      stack = client.get(stack_url(name))
      # safeguard from nil, since 'labels' field is optional
      puts Array(stack['labels'] || []).join("\n")
    end
  end
end