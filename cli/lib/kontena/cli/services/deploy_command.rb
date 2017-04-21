require_relative 'services_helper'
require_relative 'service_deploy_monitor'
require 'tty-table'

module Kontena::Cli::Services
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    option '--force', :flag, 'Force deploy even if service does not have any changes'
    option '--max-wait', '[SECONDS]', 'Monitor progress for maximum SECONDS seconds', default: 600 do |sec|
      Integer(sec)
    end

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def execute
      service_id = name

      data = {}
      data[:force] = true if force?

      deployment = spinner "Triggering deployment of service #{pastel.cyan(name)} .." do
        deploy_service(current_master.token, name, data)
      end

      monitor = ServiceDeployMonitor.new(deployment['service_id'], deployment['id'], deployment['instance_count'])
      if monitor.expected_instances > 1
        until monitor.finished? || monitor.time_elapsed > max_wait
          monitor.advance
          sleep 0.2 unless monitor.finished?
        end
        monitor.advance # once again to draw the 100%
        puts unless monitor.finished?
      else
        sleep 0.2 until monitor.finished? || monitor.time_elapsed > max_wait
      end

      if !monitor.finished? && monitor.time_elapsed > max_wait
        puts "Deployment has been running over #{max_wait} seconds, will continue in background."
        exit 0
      end

      if monitor.failed?
        $stderr.puts pastel.red("ERROR: #{monitor.reason}") if monitor.reason
        unless monitor.errored_instances.empty?
          table = TTY::Table.new(
            ['Instance', 'Node', 'Error'],
            monitor.errored_instances.map { |inst| [inst['instance_number'], inst['node'], inst['error']] }
          )
          $stderr.puts pastel.red("Instances with errors:")
          $stderr.puts table.render(:basic)
        end
        exit 1
      else
        puts pastel.green("Finished!")
        puts "Service #{pastel.cyan(name)} deployed with #{monitor.expected_instances} instances on #{monitor.node_count} nodes."
      end
    end
  end
end
