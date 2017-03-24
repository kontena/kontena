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

  class Error < StandardError
    attr_accessor :code, :message, :backtrace

    def initialize(code, message, backtrace = nil)
      self.code = code
      self.message = message
      self.backtrace = backtrace
    end
  end

  attr_reader :handlers

  def initialize
    @handlers = {}
  end

  # @param [Faye::Websocket] ws_client
  # @param [String] grid_id
  # @param [Array] message msgpack-rpc request array
  # @return [Array]
  def handle_request(ws_client, grid_id, message)
    msg_id = message[1]
    handler = message[2].split('/')[1]
    method = message[2].split('/')[2]
    if actor = handling_actor(grid_id, handler)
      begin
        result = actor.send(method, *message[3])
        send_message(ws_client, [1, msg_id, nil, result])
        unless actor.alive?
          error "actor for handler #{handler} did die, removing it from cache"
          @handlers[grid_id].delete(handler)
        end
      rescue Celluloid::DeadActorError
        error "actor for handler #{handler} is dead, removing it from cache"
        @handlers[grid_id].delete(handler)
      rescue RpcServer::Error => exc
        send_message(ws_client, [1, msg_id, {code: exc.code, message: exc.message, backtrace: exc.backtrace}, nil])
        @handlers[grid_id].delete(handler)
      rescue => exc
        error "#{exc.class.name}: #{exc.message}"
        debug exc.backtrace.join("\n")
        send_message(ws_client, [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}", backtrace: exc.backtrace}, nil])
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
    if actor = handling_actor(grid_id, handler)
      begin
        debug "rpc notification: #{actor.class.name}##{method} #{message[2]}"
        actor.async.send(method, *message[2])
      rescue Celluloid::DeadActorError
        debug "actor for handler #{handler} is dead, removing it from cache"
        @handlers[grid_id].delete(handler)
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
  def handling_actor(grid_id, name)
    return unless HANDLERS[name]

    @handlers[grid_id] ||= {}
    unless @handlers[grid_id][name]
      grid = Grid.find(grid_id)
      @handlers[grid_id][name] = HANDLERS[name].new(grid) if grid
    end

    @handlers[grid_id][name]
  end

  # @param [Faye::Websocket] ws
  # @param [Array] message
  def send_message(ws, message)
    ws.send(MessagePack.dump(message).bytes)
  end
end
