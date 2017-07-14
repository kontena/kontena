module Kontena::NetworkAdapters
  module WeaveExec
    include Kontena::Logging
    include Kontena::Helpers::WeaveHelper

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

    # @param [Array<String>] cmd
    def censor_weaveexec_password(command)
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
    def weaveexec!(*cmd, &block)
      container = Docker::Container.create(
        'Image' => weaveexec_image,
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
          "VERSION=#{weave_version}",
          "WEAVE_DEBUG=#{ENV['WEAVE_DEBUG']}",
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

      command = censor_weaveexec_password(cmd)
      status_code = response["StatusCode"]

      if status_code != 0
        output = container.streaming_logs(stdout: true, stderr: true)
        raise WeaveExecError.new(command, status_code, output)
      elsif block
        stderr = container.streaming_logs(stderr: true)
        stdout = container.streaming_logs(stdout: true)
        debug "weaveexec stream #{command}: #{stderr}"
        stdout.each_line &block # TODO: fixes #1639?
      else
        output = container.streaming_logs(stdout: true, stderr: true)
        debug "weaveexec ok: #{command}\n#{output}"
      end
    ensure
      # XXX: rescue cleanup errors
      container.delete(force: true, v: true) if container
    end

    # Wrapper that does not raise exceptions
    #
    # @see #weavexec!
    # @return [Boolean]
    def weaveexec(*cmd, &block)
      weaveexec!(*cmd, &block)
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
    def weaveexec_ps(*what)
      weaveexec('ps', *what) do |line|
        yield *line.split()
      end
    end
  end
end
