require_relative 'stacks_helper'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include StacksHelper

    banner "Deploys all services of a stack that has been installed in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    option '--[no-]wait', :flag, 'Do not wait for service deployment', default: true

    requires_current_master
    requires_current_master_token

    def execute
      deployment = nil
      spinner "Triggering deployment of stack #{pastel.cyan(name)}" do
        deployment = deploy_stack(name)
      end
      if wait?
        spinner "Waiting for deployment to start" do
          wait_for_deployment_to_start(deployment)
        end
        wait_for_deploy_to_finish(deployment)
      end
    end

    def deploy_stack(name)
      client.post("stacks/#{current_grid}/#{name}/deploy", {})
    end
  end
end
