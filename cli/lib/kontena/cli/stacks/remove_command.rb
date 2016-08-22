require_relative 'common'

module Kontena::Cli::Stacks
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Service name"

    def execute
      require_api_url
      require_token

      remove_stack(name)
    end

    private


    def remove_stack(name)
      client(token).delete("stacks/#{current_grid}/#{name}")
    end

  end
end
