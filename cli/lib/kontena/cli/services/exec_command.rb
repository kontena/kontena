require 'shellwords'
require_relative 'services_helper'

module Kontena::Cli::Services
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
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
      service_containers = client.get("services/#{parse_service_id(name)}/containers")['containers']
      service_containers.sort_by! { |container| container['instance_number'] }
      running_containers = service_containers.select{|container| container['status'] == 'running' }

      if running_containers.empty?
        exit_with_error "Service #{name} does not have any running containers"
      end

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
        else
          interactive_exec(container)
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
    # @param [Docker::Container] container
    def exec_container(container)
      if shell?
        cmd = ['sh', '-c', cmd_list.join(' ')]
      else
        cmd = cmd_list
      end

      stdout = stderr = exit_status = nil

      if !silent? && (verbose? || all?)
        spinner "Executing command on #{container['name']}" do
          stdout, stderr, exit_status = client.post("containers/#{container['id']}/exec", {cmd: cmd})

          raise Kontena::Cli::SpinAbort if exit_status != 0
        end
      else
        stdout, stderr, exit_status = client.post("containers/#{container['id']}/exec", {cmd: cmd})
      end

      stdout.each do |chunk| $stdout.write chunk end
      stderr.each do |chunk| $stderr.write chunk end

      exit exit_status if exit_status != 0 && !skip?

      return exit_status == 0
    end

    # @param [Docker::Container] container
    def interactive_exec(container)
      require 'websocket-client-simple'
      require 'io/console'

      cmd = Shellwords.join(cmd_list)
      token = require_token
      base = self
      ws = connect(ws_url(container), token)
      ws.on :message do |msg|
        base.handle_message(msg)        
      end
      ws.on :open do
        ws.send(cmd)
      end
      ws.on :close do |e|
        exit 1
      end
      
      stdin_thread = Thread.new {
        STDIN.raw {
          while char = STDIN.readpartial(1024)
            ws.send(char)
          end
        }
      }
      stdin_thread.join
    end

    # @param [Websocket::Frame::Incoming] msg
    def handle_message(msg)
      data = JSON.parse(msg.data)
      if data
        if data['exit']
          exit data['exit'].to_i
        else
          $stdout << data['chunk']
        end
      end
    rescue => exc
      STDERR << exc.message
    end

    # @param [Hash] container
    # @return [String]
    def ws_url(container)
      "#{require_current_master.url.sub('http', 'ws')}/v1/containers/#{container['id']}/exec?interactive=true"
    end

    # @param [String] url
    # @param [String] token
    # @return [WebSocket::Client::Simple]
    def connect(url, token)
      WebSocket::Client::Simple.connect(url, {
        headers: {
          'Authorization' => "Bearer #{token.access_token}",
          'Accept' => 'application/json'
        }
      })
    end
  end
end