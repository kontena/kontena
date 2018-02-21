require_relative 'common'
require_relative 'stacks_helper'

module Kontena::Cli::Stacks
  class StopCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common
    include StacksHelper # XXX: must be after Common, because that includes ServiceHelper, which has similarly named methods >_>

    banner "Stops all services of a stack"

    parameter "NAME ...", "Stack name", attribute_name: :names
    option '--[no-]wait', :flag, 'Wait for stack services to stop', default: true

    requires_current_master
    requires_current_master_token

    def execute
      names.each do |name|
        deployment = spinner "Stopping stack #{name} services" do
          client.post("stacks/#{current_grid}/#{name}/stop", {})
        end

        wait_for_deploy_to_finish(deployment) if wait?
      end
    end
  end
end
