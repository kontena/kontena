require_relative 'stacks_helper'
require_relative 'stack_deploy_monitor'
require 'tty-cursor'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include StacksHelper

    banner "Deploys all services of a stack that has been installed in a grid on Kontena Master"

    parameter "NAME", "Stack name"

    option '--max-wait', '[SECONDS]', 'Monitor progress for maximum SECONDS seconds', default: 600 do |sec|
      Integer(sec)
    end

    requires_current_master
    requires_current_master_token

    def execute
      deployment = nil
      spinner "Triggering deployment of stack #{pastel.cyan(name)}" do
        deployment = deploy_stack(name)
      end
      spinner "Waiting for deployment to start" do
        wait_for_deployment_to_start(deployment)
      end

      monitor = StackDeployMonitor.new(name, deployment['stack_id'], deployment['id'])

      monitor.make_room

      until monitor.finished? || monitor.time_elapsed > max_wait
        monitor.advance
        sleep 0.2 unless monitor.finished?
      end
      monitor.advance # once again to draw the 100%
      puts unless monitor.finished?

      if !monitor.finished? && monitor.time_elapsed > max_wait
        puts "Deployment has been running over #{max_wait} seconds, will continue in background."
        exit 0
      end

      if monitor.failed?
        $stderr.puts pastel.red("ERROR: #{monitor.throttled['error']}") if monitor.throttled['error']
        monitor.errored_services.each do |svc|
          $stderr.puts pastel.red("Service #{svc['service_id']} failed: #{svc['error']}")
          svc['instance_deploys'].select { |svc| svc['state'] == 'error' }.group_by { |svc| svc['node'] }.each do |node, instances|
            $stderr.puts "Instance deploy errors on node #{node}:"
            instances.select { |ins| ins['state'] == 'error' }.each do |instance|
              $stderr.puts " - #{instance['error']}"
            end
          end
        end
        exit 1
      else
        puts pastel.green("Finished!")
        puts "Stack #{pastel.cyan(name)} deployed."
      end
    ensure
      print TTY::Cursor.show
    end

    def deploy_stack(name)
      client.post("stacks/#{current_grid}/#{name}/deploy", {})
    end
  end
end
