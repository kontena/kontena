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

  class WeaveExecutor
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

    WEAVE_DEBUG = ENV['WEAVE_DEBUG']
    IMAGE = "#{WEAVEEXEC_IMAGE}:#{WEAVE_VERSION}"

    # @param [Array<String>] cmd
    def censor_password(command)
      if command.include?('--password')
        cmd = command.dup
        passwd_index = cmd.index('--password')
        cmd[passwd_index + 1] = '<redacted>'

        cmd
      else
        command
      end
    end

    # @param [Array<String>] *cmd
    # @raise [Docker::Error]
    # @raise [WeaveExecError]
    # @yield [line] Each line of output
    def run(*cmd, &block)
      container = Docker::Container.create(
        'Image' => IMAGE,
        'Cmd' => ['--local'] + cmd,
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
      response = container.wait

      command = censor_password(cmd)
      status_code = response["StatusCode"]

      if status_code != 0
        output = container.streaming_logs(stdout: true, stderr: true)
        raise WeaveExecError.new(command, status_code, output)
      elsif block
        stderr = container.streaming_logs(stderr: true)
        stdout = container.streaming_logs(stdout: true)
        debug "weaveexec stream #{command}:\n#{stderr}"
        stdout.each_line &block
      else
        output = container.streaming_logs(stdout: true, stderr: true)
        debug "weaveexec ok: #{command}\n#{output}"
      end
    ensure
      begin
        container.delete(force: true, v: true) if container
      rescue Docker::Error::DockerError => exc
        # known cases of storage driver errors causing container delete to fail (#1631)
        # can't do anything sensible to recover from delete errors
        # no reason to have the weavexec command itself fail either
        # TODO: separate task to cleanup orphaned containers?
        warn "weaveexec container cleanup failed: #{exc}"
      end
    end

    # Wrapper that aborts celluloid calls on exceptions
    def weaveexec!(*cmd, &block)
      run(*cmd, &block)
    rescue => exc
      abort exc
    end

    # Wrapper that does not raise exceptions
    #
    # @see #weavexec!
    # @return [Boolean]
    def weaveexec(*cmd, &block)
      run(*cmd, &block)
    rescue Docker::Error => exc
      error "weaveexec #{cmd}: #{exc}"
      return false
    rescue WeaveExecError => exc
      error exc
      return false
    else
      return true
    end

    # List network information for container(s)
    #
    # @param [Array<String>] what for given Docker IDs, 'weave:expose', or all
    # @yield [name, mac, *cidrs]
    # @yieldparam [Array<String>] cidrs
    # @return [Boolean]
    def ps!(*what)
      weaveexec!('ps', *what) do |line|
        yield *line.split()
      end
    end
  end
end
