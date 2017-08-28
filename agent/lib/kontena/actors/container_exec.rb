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

    # @param [String] cmd
    # @param [Boolean] tty
    # @param [Boolean] stdin
    def run(cmd, tty = false, stdin = false)
      info "starting command: #{cmd} (tty: #{tty}, stdin: #{stdin})"
      exit_code = 0
      opts = {tty: tty}
      opts[:stdin] = @read_pipe if stdin
      defer {
        begin
          if tty
            _, _, exit_code = @container.exec(cmd, opts) do |chunk|
              self.handle_stream_chunk('stdout'.freeze, chunk)
            end
          else
            _, _, exit_code = @container.exec(cmd, opts) do |stream, chunk|
              self.handle_stream_chunk(stream, chunk)
            end
          end
        ensure
          # the Docker::Container#exec leaves the stdin pipe open
          @read_pipe.close # ensure any input() task will fail
        end
      }
    ensure 
      info "command finished: #{cmd} with code #{exit_code}"
      shutdown(exit_code)
    end

    # @param [String] stream
    # @param [String] chunk
    def handle_stream_chunk(stream, chunk)
      rpc_client.notification('/container_exec/output', [@uuid, stream, chunk.force_encoding(Encoding::UTF_8)])
    end

    # @param [Integer] exit_code
    def shutdown(exit_code)
      rpc_client.notification('/container_exec/exit', [@uuid, exit_code])
      self.terminate
    end
  end
end
