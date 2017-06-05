require 'shellwords'
require_relative 'services_helper'
require_relative '../helpers/exec_helper'

module Kontena::Cli::Services
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::ExecHelper
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "CMD ...", "Command"

    option ["-i", "--instance"], "INSTANCE", "Exec on given numbered instance, default first running" do |value| Integer(value) end
    option ["-a", "--all"], :flag, "Exec on all running instances"
    option ["--shell"], :flag, "Execute as a shell command"
    option ["--interactive"], :flag, "Keep stdin open"
    option ["--skip"], :flag, "Skip failed instances when executing --all"
    option ["--silent"], :flag, "Do not show exec status"
    option ["--verbose"], :flag, "Show exec status"

    requires_current_master
    requires_current_grid

    def execute
      exit_with_error "--interactive cannot be used with --all" if all? && interactive?

      service_containers = client.get("services/#{parse_service_id(name)}/containers")['containers']
      service_containers.sort_by! { |container| container['instance_number'] }
      running_containers = service_containers.select{|container| container['status'] == 'running' }

      exit_with_error "Service #{name} does not have any running containers" if running_containers.empty?

      if all?
        ret = true
        service_containers.each do |container|
          if container['status'] == 'running'
            if !exec_container(container)
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
        elsif interactive?
          interactive_exec(container)
        else
          exec_container(container)
        end
      else
        if interactive?
          interactive_exec(running_containers.first)
        else
          exec_container(running_containers.first)
        end
      end
    end

    # Exits if exec returns with non-zero
    # @param [Hash] container
    def exec_container(container)
      exit_status = nil
      if !silent? && (verbose? || all?)
        spinner "Executing command on #{container['name']}" do
          exit_status = normal_exec(container)

          raise Kontena::Cli::SpinAbort if exit_status != 0
        end
      else
        exit_status = normal_exec(container)
      end

      exit exit_status if exit_status != 0 && !skip?

      return exit_status == 0
    end

    # @param [Hash] container
    # @return [Boolean]
    def normal_exec(container)
      base = self
      cmd = JSON.dump({ cmd: cmd_list })
      exit_status = nil
      token = require_token
      url = ws_url(container['id'])
      url << 'shell=true' if shell?
      ws = connect(url, token)
      ws.on :message do |msg|
        data = base.parse_message(msg)
        if data
          if data['exit']
            exit_status = data['exit'].to_i
          elsif data['stream'] == 'stdout'
            $stdout << data['chunk']
          else
            $stderr << data['chunk']
          end
        end
      end
      ws.on :open do
        ws.text(cmd)
      end
      ws.on :close do |e|
        exit_status = 1 if exit_status.nil? && e.code != 1000
      end
      ws.connect

      sleep 0.01 until !exit_status.nil?

      exit_status
    end

    # @param [Hash] container
    def interactive_exec(container)
      token = require_token
      cmd = JSON.dump({ cmd: cmd_list })
      base = self
      url = ws_url(container['id']) << 'interactive=true'
      url << '&shell=true' if shell?
      ws = connect(url, token)
      ws.on :message do |msg|
        base.handle_message(msg)
      end
      ws.on :open do
        ws.text(cmd)
      end
      ws.on :close do |e|
        exit 1 if e.code != 1000
      end
      ws.connect

      stream_stdin_to_ws(ws).join
    end
  end
end
