module Rpc 
  class ContainerExecHandler
    include Logging

    def initialize(grid)
      @grid = grid
    end

    def output(uuid, stream, chunk)
      MongoPubsub.publish("container_exec:#{uuid}", {stream: stream, chunk: chunk})
    end

    def exit(uuid, exit_code)
      MongoPubsub.publish("container_exec:#{uuid}", {exit: exit_code})
    end
  end
end