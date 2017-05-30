require_relative 'rpc/container_handler'
require_relative 'rpc/node_handler'
require_relative 'rpc/node_service_pod_handler'

class RpcServer
  include Celluloid
  include Logging

  HANDLERS = {
    'containers' => Rpc::ContainerHandler,
    'nodes' => Rpc::NodeHandler,
    'node_service_pods' => Rpc::NodeServicePodHandler,
    'node_volumes' => Rpc::NodeVolumeHandler
  }

  finalizer :finalize

  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  attr_reader :handlers

  # @param [SizedQueue] queue
  def initialize(queue)
    @queue = queue
    @handlers = {}
    @counter = 0
    @processing = false
  end

  def process!
    @processing = true
    while @processing && data = @queue.pop
      @counter += 1
      size = data.size
      if size == 2
        handle_notification(data[0], data[1])
      elsif size == 3
        handle_request(data[0], data[1], data[2])
      end
      Thread.pass
    end
  end

  # @param [Faye::Websocket] ws_client
  # @param [String] grid_id
  # @param [Array] message msgpack-rpc request array
  # @return [Array]
  def handle_request(ws_client, grid_id, message)
    msg_id = message[1]
    handler = message[2].split('/')[1]
    method = message[2].split('/')[2]
    if instance = handling_instance(grid_id, handler)
      begin
        result = instance.send(method, *message[3])
        send_message(ws_client, [1, msg_id, nil, result])
      rescue RpcServer::Error => exc
        send_message(ws_client, [1, msg_id, {code: exc.code, message: exc.message}, nil])
        @handlers[grid_id].delete(handler)
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        debug exc.backtrace.join("\n")
        send_message(ws_client, [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}"}, nil])
        @handlers[grid_id].delete(handler)
      end
    else
      warn "handler #{handler} not implemented"
      send_message(ws_client, [1, msg_id, {code: 501, error: 'service not implemented'}, nil])
    end
  end

  # @param [String] grid_id
  # @param [Array] message msgpack-rpc notification array
  def handle_notification(grid_id, message)
    handler = message[1].split('/')[1]
    method = message[1].split('/')[2]
    if instance = handling_instance(grid_id, handler)
      begin
        instance.send(method, *message[2])
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        error exc.backtrace.join("\n")
        @handlers[grid_id].delete(handler)
      end
    else
      warn "handler #{handler} not implemented"
    end
  end

  # @param [String] grid_id
  # @param [String] name
  # @return [Object]
  def handling_instance(grid_id, name)
    return unless HANDLERS[name]

    @handlers[grid_id] ||= {}
    unless @handlers[grid_id][name]
      grid = Grid.find(grid_id)
      if grid
        @handlers[grid_id][name] = HANDLERS[name].new(grid)
      end
    end

    @handlers[grid_id][name]
  end

  # @param [Faye::Websocket] ws
  # @param [Object] message
  def send_message(ws, message)
    EM.next_tick { # important to push sending back to EM reactor thread
      ws.send(MessagePack.dump(message.as_json).bytes)
    }
  end

  def finalize
    @processing = false
  end
end
