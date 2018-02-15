require_relative 'common'

module Kontena::Cli::Stacks
  class StopCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Stops all services of a stack"

    parameter "NAME ...", "Stack name", attribute_name: :names

    requires_current_master
    requires_current_master_token

    def execute
      names.each do |name|
        spinner "Sending stop signal for stack #{name} services" do
          client.post("stacks/#{current_grid}/#{name}/stop", {})
        end
      end
    end
  end
end
