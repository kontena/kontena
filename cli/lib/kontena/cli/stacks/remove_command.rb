require_relative 'common'

module Kontena::Cli::Stacks
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Service name"

    requires_current_master_token

    def execute
      remove_stack(name)
    end

    private


    def remove_stack(name)
      client.delete("stacks/#{current_grid}/#{name}")
    end

  end
end
