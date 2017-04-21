require 'tty-cursor'
require 'tty-progressbar'
require 'kontena/cli/services/service_deploy_monitor'

module Kontena::Cli::Stacks
  class StackDeployMonitor
    include Kontena::Cli::Common

    ERROR = 'error'.freeze
    ONGOING = 'ongoing'.freeze
    SUCCESS = 'success'.freeze
    CREATED = 'created'.freeze

    FINISHED_STATES = [SUCCESS, ERROR].freeze
    RUNNING_STATES = [ONGOING, CREATED].freeze

    INTERVAL = 0.5

    attr_reader :stack_name, :stack_id, :deployment_id

    def initialize(stack_name, stack_id, deployment_id)
      @stack_name = stack_name
      @stack_id = stack_id
      @deployment_id = deployment_id
      @start_time = Time.now.to_i
    end

    def time_elapsed
      Time.now.to_i - @start_time
    end

    def stack_info
      @stack_info ||= client.get("stacks/#{current_grid}/#{stack_name}")
    end

    def expected_services
      @expected_services ||= Hash[*stack_info['services'].flat_map { |svc| [svc['name'], svc] }]
    end

    def cursor
      TTY::Cursor
    end

    def got_services?
      !expected_services.empty?
    end

    def service_lines
      @service_lines = got_services? ? expected_services.size + 1 : 0
    end

    def make_room
      cursor.invisible do
        print "\n" # spacer
        print pastel.green("Total:") + "\n\n" # header + room for total progress bar
        puts pastel.green("Services:") if got_services?
        expected_services.each do |name, svc|
          puts pastel.cyan("#{name} waiting to start..")
        end
      end
    end

    # expects cursor is positioned on the bottom row
    def on_total_line(&block)
      cursor.invisible do
        print cursor.up(expected_services.size + 1) if got_services?
        print cursor.up(1) + cursor.column(1)
        yield
        print cursor.down(1)
        print cursor.down(expected_services.size + 1) if got_services?
        print cursor.column(1)
      end
    end

    # expects cursor is positioned on the bottom row
    def on_service_line(svc_idx, &block)
      cursor.invisible do
        print cursor.up(expected_services.size)
        print cursor.down(svc_idx) unless svc_idx.zero?
        print cursor.column(1)
        yield
        print cursor.column(1)
        print cursor.down(expected_services.size - svc_idx)
      end
    end

    def total_bar
      @total_bar ||= TTY::ProgressBar.new(
        " :bar :percent :eta #{pastel.cyan('[')}:current/#{expected_services.size} services done#{pastel.cyan(']')}",
        total: expected_services.size,
        complete: pastel.green(glyph(:black_square)),
        incomplete: pastel.red(glyph(:white_square))
      )
    end

    def advance_total
      on_total_line do
        total_bar.advance(finished_services.size - total_bar.current)
        print cursor.up(1) if total_bar.complete? # it newlines when finishing, need to go back
      end
    end

    def service_monitors
      @service_monitors ||= expected_services.map do |svc_name, svc|
        Kontena::Cli::Services::ServiceDeployMonitor.new(svc['id'], svc['deploy_opts']['_id']['$oid'], svc['instances'], self)
      end
    end

    def advance_services
      return nil unless got_services?
      on_total_line do
        print cursor.down(2)
        service_monitors.each do |monitor|
          if !monitor.started?
            print cursor.clear_line + pastel.cyan("#{monitor.service_id} waiting to start ...")
          elsif monitor.failed?
            print cursor.clear_line + pastel.red("#{monitor.service_id} error: #{monitor.fail_reason}")
          elsif monitor.bar.complete?
            print cursor.clear_line + pastel.green("#{monitor.service_id} ready with #{monitor.expected_instances} instances on #{monitor.node_count} nodes")
          else
            monitor.advance
            print cursor.clear_line_after
            if monitor.bar.complete? # if advance finishes, the cursor is moved to next line
              print cursor.up(1) # so need to go back to keep in sync
            end
          end
          print cursor.down(1)
        end
      end
    end

    def advance
      advance_total
      advance_services
    end

    def status
      #{"id"=>"58f8b6731246ae0008000194", "stack_id"=>"test/rock", "created_at"=>"2017-04-20T13:24:03.926Z", "state"=>"error", "service_deploys"=>[{"id"=>"58f8b6741246ae0008000196", "created_at"=>"2017-04-20T13:24:04.039Z", "started_at"=>"2017-04-20T13:24:04.629+00:00", "finished_at"=>"2017-04-20T13:24:07.875+00:00", "service_id"=>"test/rock/mongo", "state"=>"error", "reason"=>"halting deploy of test/rock/mongo, one or more instances failed", "instance_count"=>1, "instance_deploys"=>[{"instance_number"=>1, "node"=>"misty-dust-55", "state"=>"error", "error"=>"GridServiceInstanceDeployer::ServiceError: Docker::Error::ConflictError: Conflict. The name \"/rock.mongo-1-volumes\" is already in use by container 5c55136d0e2d55489067cf24a9285d5d1d2d45a9dd644b5de2fb242d7a24507b. You have to remove (or rename) that container to be able to reuse that name.\n"}]}]}
      client.get("stacks/#{stack_id}/deploys/#{deployment_id}")
    end

    def throttled
      if @last_result && @last_request && (Time.now.to_f - @last_request < INTERVAL)
        @last_result
      else
        @last_request = Time.now.to_f
        @last_result = status
      end
    end

    def finished?
      FINISHED_STATES.include?(throttled['state'])
    end

    def failed?
      throttled['state'] == 'error'
    end

    def finished_services
      if finished?
        throttled['service_deploys']
      else
        throttled['service_deploys'].select { |svc| !svc['finished_at'].nil? } || []
      end
    end

    def errored_services
      throttled['service_deploys'].select { |svc| svc['state'] == ERROR } || []
    end
  end
end
