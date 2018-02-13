require 'shellwords'
require 'json'
require_relative 'services_helper'
require_relative '../helpers/exec_helper'

module Kontena::Cli::Services
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::ExecHelper
    include ServicesHelper

    Clamp.allow_options_after_parameters = false

    class ExecExit < StandardError
      attr_reader :exit_status

      def initialize(exit_status, message = nil)
        super(message)
        @exit_status = exit_status
      end
    end

    parameter "NAME", "Service name"
    parameter "CMD ...", "Command"

    option ["--instance"], "INSTANCE", "Exec on given numbered instance, default first running" do |value| Integer(value) end
    option ["-a", "--all"], :flag, "Exec on all running instances"
    option ["--shell"], :flag, "Execute as a shell command", default: false
    option ["-i", "--interactive"], :flag, "Keep stdin open", default: false
    option ["-t", "--tty"], :flag, "Allocate a pseudo-TTY", default: false
    option ["--skip"], :flag, "Skip failed instances when executing --all"
    option ["--silent"], :flag, "Do not show exec status"
    option ["--verbose"], :flag, "Show exec status"

    requires_current_master
    requires_current_grid

    def execute
      exit_with_error "the input device is not a TTY" if tty? && !STDIN.tty?
      exit_with_error "--interactive cannot be used with --all" if all? && interactive?

      service_containers = client.get("services/#{parse_service_id(name)}/containers")['containers']
      service_containers.sort_by! { |container| container['instance_number'] }
      running_containers = service_containers.select{|container| container['status'] == 'running' }

      exit_with_error "Service #{name} does not have any running containers" if running_containers.empty?

      if all?
        ret = true
        service_containers.each do |container|
          if container['status'] == 'running'
            if !execute_container(container)
              ret = false
            end
          else
            warning "Service #{name} container #{container['name']} is #{container['status']}, skipping"
          end
        end
        return ret
      elsif instance
        if !(container = service_containers.find{|c| c['instance_number'] == instance})
          exit_with_error "Service #{name} does not have container instance #{instance}"
        elsif container['status'] != 'running'
          exit_with_error "Service #{name} container #{container['name']} is not running, it is #{container['status']}"
        else
          execute_container(container)
        end
      else
        execute_container(running_containers.first)
      end
    end

    # Run block with spinner by default if --all, or when using --verbose.
    # Do not use spinner if --silent.
    def maybe_spinner(msg, &block)
      if (all? || verbose?) && !silent?
        spinner(msg, &block)
      else
        yield
      end
    end

    # @param [Hash] container
    # @raise [SystemExit] if exec exits with non-zero status, and not --skip
    # @return [true] exit exit status zero
    # @return [false] exit exit status non-zero and --skip
    def execute_container(container)
      maybe_spinner "Executing command on #{container['name']}" do
        exit_status = container_exec(container['id'], self.cmd_list,
          interactive: interactive?,
          shell: shell?,
          tty: tty?,
        )
        raise ExecExit.new(exit_status) unless exit_status.zero?
      end
    rescue ExecExit => exc
      if skip?
        return false
      else
        exit exc.exit_status
      end
    else
      return true
    end
  end
end
