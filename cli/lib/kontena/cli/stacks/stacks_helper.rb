module Kontena::Cli::Stacks
  module StacksHelper

    def wait_for_deployment_to_start(deployment, timeout = 600)
      started = false
      Timeout::timeout(timeout) do
        while deployment['state'] == 'created'
          sleep 1
          deployment = client.get("stacks/#{deployment['stack_id']}/deploys/#{deployment['id']}")
        end
        if deployment['state'] == 'error'
          puts "Stack deploy failed"
          deployment['service_deploys'].each do |service_deploy|
            if service_deploy['state'] == 'error'
              puts " - #{service_deploy['reason']}"
            end
          end

          abort
        end
      end

      started
    rescue Timeout::Error
      raise 'deploy timed out'
    end

    # @param [Hash] deployment
    # @return [Boolean]
    def wait_for_deploy_to_finish(deployment, timeout = 600)
      deployed = false
      states = %w(success error)
      tracked_services = []
      Timeout::timeout(timeout) do
        until deployed
          deployment = client.get("stacks/#{deployment['stack_id']}/deploys/#{deployment['id']}")
          service_deploy = deployment['service_deploys'].find{ |s| s['state'] == 'ongoing' }
          if service_deploy
            tracked_services << service_deploy['id']
            wait_for_service_deploy(service_deploy)
          end
          if states.include?(deployment['state'])
            deployed = true
            deployment['service_deploys'].select{ |s| !tracked_services.include?(s['id']) }.each do |s|
              wait_for_service_deploy(s)
            end
          else
            sleep 1
          end
        end
        if deployment['state'] == 'error'
          deployment['service_deploys'].each do |service_deploy|
            if service_deploy['state'] == 'error'
              $stderr.puts "Deployment of service #{pastel.cyan(service_deploy['service_id'])} failed:"
              $stderr.puts "  - #{service_deploy['reason'].strip}"
              service_deploy['instance_deploys'].each do |instance_deploy|
                if instance_deploy['state'] == 'error'
                  $stderr.puts "  - " + "#{instance_deploy['error'].strip} (on node #{pastel.cyan(instance_deploy['node'])})"
                end
              end
            end
          end
          abort
        end
      end

      deployed
    rescue Timeout::Error
      raise 'deploy timed out'
    end

    def wait_for_service_deploy(service_deploy)
      name = service_deploy['service_id'].split('/')[-1]
      spinner "Deploying service #{pastel.cyan(name)}" do |spin|
        until service_deploy['finished_at']
          sleep 1
          service_deploy = client.get("services/#{service_deploy['service_id']}/deploys/#{service_deploy['id']}")
        end
        spin.fail if service_deploy['state'] == 'error'
      end
    end
  end
end
