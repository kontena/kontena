require_relative '../helpers/rpc_helper'

module Kontena::Actors
  class ContainerExec
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    exclusive :input

    attr_reader :uuid

    # @param [Docker::Container] container
    def initialize(container)
      @uuid = SecureRandom.uuid
      @container = container
      @read_pipe, @write_pipe = IO.pipe
      info "initialized (session #{@uuid})"
    end

    # @param [String] input
    def input(input)
      if !@write_pipe
        warn "stdin write closed"
      elsif input.nil?
        @write_pipe.close
      else
        @write_pipe.write(input)
      end
    rescue Errno::EPIPE => exc
      warn "stdin write error: #{exc}"
      @write_pipe.close
      @write_pipe = nil
    end

    # @param [Hash] size
    # @option size [Integer] width
    # @option size [Integer] height
    def tty_resize(size)
      return unless @container_exec

      begin
        @container_exec.resize({
          'w' => size['width'], 'h' => size['height']
        })
        info "tty resized to #{size['width']}x#{size['height']}"
      rescue Docker::Error::NotFoundError => exc
        # The Docker::Exec#resize races with the Docker::Exec#start, and the
        # resize (POST /exec/.../resize) will fail if the exec process is not
        # yet running:
        #   Docker::Error::NotFoundError: containerd: process not found for container
        if exc.message.include?('process not found')
          # This needs to wait for the start => POST /exec/.../start HTTP request
          # to return the response headers, but the Docker::Exec#start API does
          # not tell us when that happens (it only yields on the first streaming
          # chunk, or returns when the exec exits)... just retry instead.
          sleep 0.1
          retry if @container_exec
        end
      end
    end

    # @param [String] cmd
    # @param [Boolean] tty
    # @param [Boolean] stdin
    def run(cmd, tty = false, stdin = false)
      info "starting command: #{cmd} (tty: #{tty}, stdin: #{stdin})"
      exit_code = nil
      @container_exec = build_exec(cmd, tty: tty, stdin: stdin)
      defer {
        start_opts = {
          tty: tty,
          stdin: @read_pipe,
          detach: false
        }
        begin
          if tty
            _, _, exit_code = start_exec(start_opts) do |chunk|
              self.handle_stream_chunk('stdout'.freeze, chunk)
            end
          else
            _, _, exit_code = start_exec(start_opts) do |stream, chunk|
              self.handle_stream_chunk(stream, chunk)
            end
          end
        ensure
          # the Docker::Container#exec leaves the stdin pipe open
          @read_pipe.close # ensure any input() task will fail
        end
      }
    rescue Docker::Error::DockerError => exc
      warn "#{cmd} error: #{exc}"
      handle_error(exc)
    rescue Exception => exc
      error exc
      handle_error(exc)
    else
      info "#{cmd} exit with code #{exit_code}: #{cmd}"
      handle_exit(exit_code)
    ensure
      @container_exec = nil
      self.terminate
    end

    # @param [String] stream
    # @param [String] chunk
    def handle_stream_chunk(stream, chunk)
      rpc_client.notification('/container_exec/output', [@uuid, stream, chunk.force_encoding(Encoding::UTF_8)])
    end

    # @param [Integer] exit_code
    def handle_exit(exit_code)
      rpc_client.notification('/container_exec/exit', [@uuid, exit_code])
    end

    # @param [Exception] error
    def handle_error(error)
      rpc_client.notification('/container_exec/error', [@uuid, "#{error.class.name}: #{error}"])
    end

    # @param [Array<String>] command
    # @param [Boolean] stdin
    # @param [Boolean] tty
    # @return [Docker::Exec]
    def build_exec(command, stdin: false, tty: false)
      opts = {
        'Container' => @container.id,
        'AttachStdin' => stdin,
        'AttachStdout' => true,
        'AttachStderr' => true,
        'Tty' => tty,
        'Cmd' => command
      }
      opts['Env'] = ['TERM=xterm'] if tty && stdin

      # Create Exec Instance
      Docker::Exec.create(
        opts,
        @container.connection
      )
    end

    # @param [Hash] options
    # @option options [Boolean] tty
    # @option options [IO] stdin
    # @option options [Boolean] detach
    def start_exec(options, &block)
      @container_exec.start!(options, &block)
    end
  end
end
