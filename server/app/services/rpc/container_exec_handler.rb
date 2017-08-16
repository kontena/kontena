module Rpc
  class ContainerExecHandler
    include Logging

    # @params [HostNode] node
    def initialize(node)
      @node = node
    end

    def output(uuid, stream, chunk)
      MongoPubsub.publish("container_exec:#{uuid}", {stream: stream, chunk: chunk})
    end

    def exit(uuid, exit_code)
      MongoPubsub.publish("container_exec:#{uuid}", {exit: exit_code})
    end
  end
end
