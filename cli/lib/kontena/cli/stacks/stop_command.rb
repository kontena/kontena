require_relative 'common'

module Kontena::Cli::Stacks
  class StopCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Stops all services of a stack that has been installed in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      spinner "Sending stop signal for stack services" do
        client.post("stacks/#{current_grid}/#{name}/stop", {})
      end
    end

  end
end
