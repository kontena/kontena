require_relative 'common'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    def execute
      require_api_url
      token = require_token

      deployment = nil
      spinner "Deploying stack #{pastel.cyan(name)}" do
        deployment = deploy_stack(token, name)
        deployment['service_deploys'].each do |service_deploy|
          wait_for_deploy_to_finish(token, service_deploy)
        end
      end
    end

    def deploy_stack(token, name)
      client(token).post("stacks/#{current_grid}/#{name}/deploy", {})
    end

    # @param [String] token
    # @param [Hash] deployment
    # @return [Boolean]
    def wait_for_deploy_to_finish(token, deployment, timeout = 600)
      deployed = false
      Timeout::timeout(timeout) do
        until deployed
          deployment = client(token).get("services/#{deployment['service_id']}/deploys/#{deployment['id']}")
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
