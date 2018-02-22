require_relative 'rpc/container_handler'
require_relative 'rpc/container_exec_handler'
require_relative 'rpc/node_handler'
require_relative 'rpc/node_service_pod_handler'

class RpcServer
  include Celluloid
  include Logging

  QUEUE_SIZE = 1000

  def self.queue
    @queue ||= SizedQueue.new(QUEUE_SIZE)
  end

  HANDLERS = {
    'containers' => Rpc::ContainerHandler,
    'container_exec' => Rpc::ContainerExecHandler,
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
  def initialize(autostart: true)
    @queue = self.class.queue
    @handlers = {}
    @counter = 0
    @processing = false

    async.process! if autostart
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
    msg_path = message[2]
    _, handler, method = msg_path.split('/')
    if instance = handling_instance(grid_id, handler)
      start_time = Time.now
      begin
        result = instance.send(method, *message[3])
      rescue RpcServer::Error => exc
        send_message(ws_client, [1, msg_id, {code: exc.code, message: exc.message}, nil])
        @handlers[grid_id].delete(handler)
      rescue => exc
        error "request #{msg_path} => #{exc.class}: #{exc}"
        error exc
        send_message(ws_client, [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}"}, nil])
        @handlers[grid_id].delete(handler)
      else
        dt = Time.now - start_time
        debug "request #{msg_path} => #{result.class} in #{'%.3f' % dt}s"
        send_message(ws_client, [1, msg_id, nil, result])
      end
    else
      warn "handler #{msg_path} not implemented"
      send_message(ws_client, [1, msg_id, {code: 501, error: 'service not implemented'}, nil])
    end
  end

  # @param [String] grid_id
  # @param [Array] message msgpack-rpc notification array
  def handle_notification(grid_id, message)
    msg_path = message[1]
    _, handler, method = msg_path.split('/')
    if instance = handling_instance(grid_id, handler)
      start_time = Time.now
      begin
        instance.send(method, *message[2])
      rescue => exc
        error "notify #{msg_path} => #{exc.class}: #{exc}"
        error exc
        @handlers[grid_id].delete(handler)
      else
        dt = Time.now - start_time
        debug "notify #{msg_path} in #{'%.3f' % dt}s"
      end
    else
      warn "handler #{msg_path} not implemented"
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
