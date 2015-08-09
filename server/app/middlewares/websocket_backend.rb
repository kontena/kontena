require 'faye/websocket'
require 'thread'
require_relative '../services/agent/message_handler'

class WebsocketBackend
  KEEPALIVE_TIME = 45 # in seconds

  attr_reader :logger

  def initialize(app)
    @app     = app
    @clients = []
    @logger = Logger.new(STDOUT)
    @logger.level = (ENV['LOG_LEVEL'] || Logger::INFO).to_i
    @logger.progname = 'WebsocketBackend'
    @incoming_queue = Queue.new
    Agent::MessageHandler.new(@incoming_queue).run
    subscribe_to_rpc
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      req = Rack::Request.new(env)
      ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME})

      ws.on :open do |event|
        self.on_open(ws, req)
      end

      ws.on :message do |event|
        self.on_message(ws, event)
      end

      ws.on :close do |event|
        self.on_close(ws)
      end

      # Return async Rack response
      ws.rack_response
    else
      @app.call(env)
    end
  end

  ##
  # On websocket connection open
  #
  # @param [Faye::WebSocket] ws
  # @param [Rack::Request] req
  def on_open(ws, req)
    grid = Grid.find_by(token: req.env['HTTP_KONTENA_GRID_TOKEN'].to_s)
    if !grid.nil?
      node_id = req.env['HTTP_KONTENA_NODE_ID'].to_s
      node = grid.host_nodes.find_by(node_id: node_id)
      unless node
        node = grid.host_nodes.create!(node_id: node_id)
      end
      logger.info "node opened connection: #{node.name || node_id}"
      node.update_attribute(:connected, true)
      client = {
          ws: ws,
          id: node_id.to_s,
          grid_id: grid.id,
          created_at: Time.now
      }
      @clients << client
    else
      logger.error 'invalid grid token, closing connection'
      ws.close
    end
  end

  ##
  # @param [Faye::WebSocket] ws
  # @param [Faye::WebSocket::Event] event
  def on_message(ws, event)
    data = MessagePack.unpack(event.data.pack('c*'))
    if agent_message?(data)
      handle_agent_message(ws, data)
    elsif rpc_request?(data)
      handle_rpc_request(ws, data)
    elsif rpc_response?(data)
      handle_rpc_response(data)
    end
  rescue => exc
    logger.error "Cannot unpack message, reason #{exc.message}"
  end

  ##
  # @param [Object] data
  # @return [Boolean]
  def agent_message?(data)
    data.is_a?(Hash) && data['event'] && data['data']
  end

  ##
  # @param [Object] data
  # @return [Boolean]
  def rpc_response?(data)
    data.is_a?(Array) && data.size == 4 && data[0] == 1
  end

  ##
  # @param [Object] data
  # @return [Boolean]
  def rpc_request?(data)
    data.is_a?(Array) && data.size == 4 && data[0] == 0
  end

  ##
  # @param [Faye::WebSocket::Event] ws
  # @param [Hash] data
  def handle_agent_message(ws, data)
    client = client_for_ws(ws)
    if client
      @incoming_queue << {
          'grid_id' => client[:grid_id].to_s,
          'data' => data
      }
    end
  end

  ##
  # @param [Array] data
  def handle_rpc_response(data)
    MongoPubsub.publish_async('rpc_client', {message: data})
  end

  ##
  # @param [Faye::WebSocket]
  # @param [Array] data
  def handle_rpc_request(ws, data)
    client = client_for_ws(ws)
    Thread.new {
      response = RpcServer.handle_request(client[:grid_id].to_s, data)
      ws.send(MessagePack.dump(response).bytes)
    }
  end

  ##
  # On websocket connection close
  #
  # @param [Faye::WebSocket] ws
  def on_close(ws)
    client = @clients.find{|c| c[:ws] == ws}
    if client
      node = HostNode.find_by(node_id: client[:id])
      if node
        node.update_attribute(:connected, false)
        logger.info "node closed connection: #{node.name || node.node_id}"
      end
      @clients.delete(client)
    end
    ws.close
  end

  ##
  # @param [Faye::WebSocket] ws
  # @return [Hash,NilClass]
  def client_for_ws(ws)
    @clients.find{|c| c[:ws] == ws}
  end

  ##
  # @param [String] id
  # @return [Hash,NilClass]
  def client_for_id(id)
    @clients.find{|c| c[:id] == id}
  end

  def subscribe_to_rpc
    MongoPubsub.subscribe('rpc_client') do |message|
      self.on_pubsub_message(message)
    end
  end

  # @param [Hash] msg
  def on_pubsub_message(msg)
    if msg && msg.is_a?(Hash) && msg['type'] == 'request'
      client = client_for_id(msg['id'])
      if client
        EM.next_tick {
          client[:ws].send(MessagePack.dump(msg['message']).bytes)
        }
      else
        sleep 0.2
        handle_rpc_response([1, msg['message'][1], {code: 503, message: 'Node unavailable'}, nil])
      end
    end
  rescue => exc
    logger.error "on_redis_message: #{exc.message}"
  end
end
