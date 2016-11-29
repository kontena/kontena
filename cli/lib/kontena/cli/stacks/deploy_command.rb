require_relative 'common'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Deploys all services of a stack that has been installed in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      deployment = nil
      spinner "Deploying stack #{pastel.cyan(name)}" do
        deployment = deploy_stack(name)
        deployment['service_deploys'].each do |service_deploy|
          wait_for_deploy_to_finish(service_deploy)
        end
      end
    end

    def deploy_stack(name)
      client.post("stacks/#{current_grid}/#{name}/deploy", {})
    end

    # @param [Hash] deployment
    # @return [Boolean]
    def wait_for_deploy_to_finish(deployment, timeout = 600)
      deployed = false
      Timeout::timeout(timeout) do
        until deployed
          deployment = client.get("services/#{deployment['service_id']}/deploys/#{deployment['id']}")
          deployed = true if deployment['finished_at']
          sleep 1
        end
        if deployment['state'] == 'error'
          raise deployment['reason']
        end
      end

      deployed
    rescue Timeout::Error
      raise 'deploy timed out'
    end
  end
end
