require_relative 'rpc/container_handler'
require_relative 'rpc/container_exec_handler'
require_relative 'rpc/node_handler'
require_relative 'rpc/node_service_pod_handler'

class RpcServer
  include Celluloid
  include Logging

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

      node_id, rpc_message, ws_client = data
      if rpc_message[0] == 0
        handle_request(node_id, rpc_message, ws_client)
      else
        handle_notification(node_id, rpc_message)
      end
      Thread.pass
    end
  end

  # @param [Faye::Websocket] ws_client
  # @param [String] node_id
  # @param [Array] message msgpack-rpc request array
  # @return [Array]
  def handle_request(node_id, rpc_message, ws_client)
    msg_type, msg_id, rpc_method, rpc_args = rpc_message
    root, handler, method = rpc_method.split('/')

    if instance = handling_instance(node_id, handler)
      begin
        result = instance.send(method, *rpc_args)
        send_message(ws_client, [1, msg_id, nil, result])
      rescue RpcServer::Error => exc
        send_message(ws_client, [1, msg_id, {code: exc.code, message: exc.message}, nil])
        @handlers[node_id].delete(handler)
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        debug exc.backtrace.join("\n")
        send_message(ws_client, [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}"}, nil])
        @handlers[node_id].delete(handler)
      end
    else
      warn "handler #{handler} not implemented"
      send_message(ws_client, [1, msg_id, {code: 501, error: 'service not implemented'}, nil])
    end
  end

  # @param [String] node_id
  # @param [Array] message msgpack-rpc notification array
  def handle_notification(node_id, rpc_message)
    msg_type, rpc_method, rpc_args = rpc_message
    root, handler, method = rpc_method.split('/')

    if instance = handling_instance(node_id, handler)
      begin
        instance.send(method, *rpc_args)
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        error exc.backtrace.join("\n")
        @handlers[node_id].delete(handler)
      end
    else
      warn "handler #{handler} not implemented"
    end
  end

  # @param [String] node_id
  # @param [String] handler
  # @return [Object]
  def handling_instance(node_id, name)
    return unless HANDLERS[name]

    @handlers[node_id] ||= {}
    unless @handlers[node_id][name]
      node = HostNode.find(node_id)
      if node
        @handlers[node_id][name] = HANDLERS[name].new(node)
      end
    end

    @handlers[node_id][name]
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
