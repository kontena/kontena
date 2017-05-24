require 'tty-progressbar'

module Kontena
  module Cli
    module Services
      class ServiceDeployMonitor
        include Kontena::Cli::Common

        ERROR = 'error'.freeze
        ONGOING = 'ongoing'.freeze
        SUCCESS = 'success'.freeze
        CREATED = 'created'.freeze

        FINISHED_STATES = [SUCCESS, ERROR].freeze
        RUNNING_STATES = [ONGOING, CREATED].freeze

        INTERVAL = 0.5

        attr_reader :service_id, :deployment_id, :expected_instances, :stack_deploy_monitor

        def initialize(service_id, deployment_id, expected_instances, stack_deploy_monitor = nil)
          @service_id = service_id
          @deployment_id = deployment_id
          @expected_instances = expected_instances
          @stack_deploy_monitor = stack_deploy_monitor
          @start_time = Time.now.to_i
        end

        def time_elapsed
          Time.now.to_i - @start_time
        end

        def status_from_stack_deploy
          stack_deploy_monitor.throttled['service_deploys'].find { |dep| dep['service_id'] == service_id }
        end

        def started?
          stack_deploy_monitor && status_from_stack_deploy
        end

        def status
          return status_from_stack_deploy if stack_deploy_monitor
          client.get("services/#{service_id}/deploys/#{deployment_id}")
        end

        def throttled
          return status_from_stack_deploy if stack_deploy_monitor
          if @last_result && @last_request && (Time.now.to_f - @last_request < INTERVAL)
            @last_result
          else
            @last_request = Time.now.to_f
            @last_result = status
          end
        end

        def finished?
          !throttled['finished_at'].nil?
        end

        def failed?
          throttled['state'] == 'error'
        end

        def fail_reason
          throttled['reason']
        end

        def node_count
          throttled['instance_deploys'].map { |deploy| deploy['node'] }.uniq.size
        end

        def finished_instances
          if finished?
            throttled['instance_deploys']
          else
            throttled['instance_deploys'].select { |instance| FINISHED_STATES.include?(instance['state']) } || []
          end
        end

        def errored_instances
          throttled['instance_deploys'].select { |instance| instance['state'] == ERROR } || []
        end

        def succesful_instances
          throttled['instance_deploys'].select { |instance| instance['state'] == SUCCESS } || []
        end

        def ongoing_instances
          throttled['instance_deploys'].select { |instance| RUNNING_STATES.include?(instance['state']) } || []
        end

        def progress
          finished? ? expected_instances : finished_instances.size
        end

        def bar
          @bar ||= TTY::ProgressBar.new(
            " #{"#{service_id} " if stack_deploy_monitor}:bar :percent :eta #{pastel.cyan('[')}:running DEPLOYING | :success OK | :errors FAILED | :current/#{expected_instances} DONE#{pastel.cyan(']')}",
            total: expected_instances,
            complete: pastel.green(glyph(:black_square)),
            incomplete: pastel.red(glyph(:white_square))
          )
        end

        def advance
          bar.advance(
            finished_instances.size - bar.current,
            running: pastel.blue(ongoing_instances.size.to_s),
            success: pastel.green(succesful_instances.size.to_s),
            errors:  pastel.red(errored_instances.size.to_s)
          )
        end
      end
    end
  end
end
