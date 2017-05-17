require_relative 'common'

module Kontena::Cli::Stacks
  class RestartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Restarts all services of a stack that has been installed in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      spinner "Sending restart signal for stack services" do
        client.post("stacks/#{current_grid}/#{name}/restart", {})
      end
    end

  end
end
