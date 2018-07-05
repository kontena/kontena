require_relative 'common'

module Kontena::Cli::Stacks
  class RestartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Restarts all services of a stack that has been installed in a grid on Kontena Master"

    parameter "NAME ...", "Stack name", attribute_name: :names

    requires_current_master
    requires_current_master_token

    def execute
      names.each do |name|
        spinner "Sending restart signal for stack #{name} services" do
          client.post("stacks/#{current_grid}/#{name}/restart", {})
        end
      end
    end
  end
end
