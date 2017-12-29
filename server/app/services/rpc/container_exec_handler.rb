module Rpc
  class ContainerExecHandler
    include Logging

    def initialize(grid)
      @grid = grid
    end

    def output(uuid, stream, chunk)
      MasterPubsub.publish("container_exec:#{uuid}", {stream: stream, chunk: chunk})
    end

    def exit(uuid, exit_code)
      MasterPubsub.publish("container_exec:#{uuid}", {exit: exit_code})
    end

    def error(uuid, error)
      MasterPubsub.publish("container_exec:#{uuid}", {error: error})
    end
  end
end