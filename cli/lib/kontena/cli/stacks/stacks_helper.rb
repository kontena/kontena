
module Kontena::Cli::Stacks
  module StacksHelper

    # @param [Hash] deployment
    # @return [Boolean]
    def wait_for_deploy_to_finish(deployment, timeout = 600)
      deployed = false
      states = %w(success error)
      Timeout::timeout(timeout) do
        until deployed
          deployment = client.get("stacks/#{deployment['stack_id']}/deploys/#{deployment['id']}")
          deployed = true if states.include?(deployment['state'])
          sleep 1
        end
        if deployment['state'] == 'error'
          deployment['service_deploys'].each do |service_deploy|
            if service_deploy['state'] == 'error'
              puts "        #{service_deploy['reason']}"
            end
          end

          raise 'deploy failed'
        end
      end

      deployed
    rescue Timeout::Error
      raise 'deploy timed out'
    end
  end
end
