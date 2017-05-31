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
      @write_pipe.write(input)
    end

    # @param [String] cmd
    def run(cmd)
      info "starting command: #{cmd}"
      _, _, exit_code = @container.exec(cmd) do |stream, chunk|
        rpc_client.notification('/container_exec/output', [@uuid, stream, chunk.force_encoding(Encoding::UTF_8)])
      end
    ensure 
      info "command finished: #{cmd} with code #{exit_code}"
      shutdown(cmd, exit_code)
    end

    # @param [String] cmd
    def interactive(cmd)
      info "starting interactive session: #{cmd}"
      opts = {tty: true, stdin: @read_pipe}
      exit_code = 0
      defer {
        _, _, exit_code = @container.exec(cmd, opts) do |data|
          rpc_client.notification('/container_exec/output', [@uuid, 'stdout', data.force_encoding(Encoding::UTF_8)])
        end
      }
    ensure 
      info "interactive session finished: #{cmd} with code #{exit_code}"
      shutdown(cmd, exit_code)
    end

    # @param [String] cmd
    # @param [Integer] exit_code
    def shutdown(cmd, exit_code)
      rpc_client.notification('/container_exec/exit', [@uuid, exit_code])
      self.terminate
    end
  end
end
