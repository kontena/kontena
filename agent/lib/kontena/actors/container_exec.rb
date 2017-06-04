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
      @last_input = Time.now.to_i
      info "initialized (session #{@uuid})"

      every(60) { self.check_activity }
    end

    def check_activity
      if @last_input < (Time.now.to_i - 60*60)
        warn "shutting down because no activity in last hour"
        shutdown(1)
      end
    end

    # @param [String] input
    def input(input)
      if input.nil?
        @write_pipe.close
      else
        @last_input = Time.now.to_i
        @write_pipe.write(input)
      end
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
        if tty
          _, _, exit_code = @container.exec(cmd, opts) do |chunk|
            self.handle_stream_chunk('stdout'.freeze, chunk)
          end
        else 
          _, _, exit_code = @container.exec(cmd, opts) do |stream, chunk|
            self.handle_stream_chunk(stream, chunk)
          end
        end
      }
    ensure 
      info "command finished: #{cmd} with code #{exit_code}"
      shutdown(exit_code)
    end

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
