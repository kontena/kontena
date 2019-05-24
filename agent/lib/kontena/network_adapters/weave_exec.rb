require_relative '../helpers/weave_helper'

module Kontena::NetworkAdapters
  class WeaveExecError < StandardError
    def initialize(command, status_code, output)
      @command = command
      @status_code = status_code
      @output = output
    end

    def to_s
      "weaveexec exit #{@status_code}: #{@command}\n#{@output}"
    end
  end

  class WeaveExec
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    WEAVE_DEBUG = ENV['WEAVE_DEBUG']
    IMAGE = "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"

    # @raise [Docker::Error]
    # @raise [WeaveExecError]
    def self.weaveexec(*cmd, &block)
      exec = new(cmd)
      exec.run(&block)
    end

    # List network information for container(s)
    #
    # @param [Array<String>] what for given Docker IDs, 'weave:expose', or all
    # @yield [name, mac, *cidrs]
    # @yieldparam [Array<String>] cidrs
    # @raise [Docker::Error]
    # @raise [WeaveExecError]
    # @return [Boolean]
    def self.ps(*what)
      weaveexec('ps', *what) do |line|
        yield *line.split()
      end
    end

    # @param [Array<String>] cmd
    def initialize(cmd)
      @cmd = cmd
    end

    # @return [Array<String>]
    def censored_command
      if @cmd.include?('--password')
        cmd = @cmd.dup
        passwd_index = cmd.index('--password')
        cmd[passwd_index + 1] = '<redacted>'

        cmd
      else
        @cmd
      end
    end

    # @raise [Docker::Error]
    # @return [Docker::Container]
    def run_container
      container = Docker::Container.create(
        'Image' => IMAGE,
        'Cmd' => @cmd,
        'Volumes' => {
          '/var/run/docker.sock' => {},
          '/host' => {}
        },
        'Labels' => {
          'io.kontena.container.skip_logs' => '1'
        },
        'Env' => [
          'HOST_ROOT=/host',
          "VERSION=#{WEAVE_VERSION}",
          "WEAVE_DEBUG=#{WEAVE_DEBUG}",
        ],
        'HostConfig' => {
          'Privileged' => true,
          'NetworkMode' => 'host',
          'PidMode' => 'host',
          'Binds' => [
            '/var/run/docker.sock:/var/run/docker.sock',
            '/:/host'
          ]
        }
      )
      container.start!
      container
    end

    # @param container [Docker::Container]
    def cleanup_container(container)
      container.delete(force: true, v: true)
    rescue Docker::Error::DockerError => exc
      # known cases of storage driver errors causing container delete to fail (#1631)
      # can't do anything sensible to recover from delete errors
      # no reason to have the weavexec command itself fail either
      # TODO: separate task to cleanup orphaned containers?
      warn "weaveexec container cleanup failed: #{exc}"
    end

    # @raise [Docker::Error]
    # @raise [WeaveExecError]
    # @yield [line] Each line of output
    def run(&block)
      container = run_container

      response = container.wait
      status_code = response["StatusCode"]

      if status_code != 0
        output = container.streaming_logs(stdout: true, stderr: true)
        raise WeaveExecError.new(command, status_code, output)
      elsif block
        stderr = container.streaming_logs(stderr: true)
        stdout = container.streaming_logs(stdout: true)
        debug "weaveexec stream #{self.censored_command}:\n#{stderr}"
        stdout.each_line &block
      else
        output = container.streaming_logs(stdout: true, stderr: true)
        debug "weaveexec ok: #{self.censored_command}\n#{output}"
      end
    ensure
      cleanup_container(container) if container
    end
  end
end
