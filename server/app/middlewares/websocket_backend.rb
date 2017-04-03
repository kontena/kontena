require 'faye/websocket'
require_relative '../services/rpc_server'
require_relative '../services/agent/node_plugger'
require_relative '../services/agent/node_unplugger'

class WebsocketBackend
  KEEPALIVE_TIME = 30 # in seconds
  RPC_MSG_TYPES = %w(request notify)

  attr_reader :logger

  def initialize(app)
    @app     = app
    @clients = []
    @logger = Logger.new(STDOUT)
    @logger.level = (ENV['LOG_LEVEL'] || Logger::INFO).to_i
    @logger.progname = 'WebsocketBackend'
    @queue = SizedQueue.new(1000)
    @rpc_server = RpcServer.new(@queue)
    @rpc_server.async.process!
    subscribe_to_rpc_channel
    watch_connections
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      req = Rack::Request.new(env)
      ws = Faye::WebSocket.new(env)

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
      labels = req.env['HTTP_KONTENA_NODE_LABELS'].to_s.split(',')
      unless node
        node = grid.host_nodes.create!(node_id: node_id, labels: labels)
      end

      node_plugger = Agent::NodePlugger.new(grid, node)
      client = {
          ws: ws,
          id: node_id.to_s,
          node_id: node.id,
          grid_id: grid.id,
          created_at: Time.now
      }
      @clients << client

      agent_version = req.env['HTTP_KONTENA_VERSION'].to_s
      unless self.valid_agent_version?(agent_version)
        logger.error "version mismatch: server (#{Server::VERSION}), node (#{agent_version})"
        node_plugger.send_master_info
        self.handle_invalid_agent_version(ws, node)
        return
      end

      logger.info "node opened connection: #{node.name || node_id}, labels: #{labels}"
      node_plugger.plugin!
    else
      logger.error 'invalid grid token, closing connection'
      ws.close(4001)
    end
  rescue => exc
    logger.error "#{exc.class.name}: #{exc.message}"
  end

  ##
  # @param [Faye::WebSocket] ws
  # @param [Faye::WebSocket::Event] event
  def on_message(ws, event)
    data = MessagePack.unpack(event.data.pack('c*'))
    if rpc_notification?(data)
      handle_rpc_notification(ws, data)
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
  def rpc_request?(data)
    data.is_a?(Array) && data.size == 4 && data[0] == 0
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
  def rpc_notification?(data)
    data.is_a?(Array) && data.size == 3 && data[0] == 2
  end

  ##
  # @param [Array] data
  def handle_rpc_response(data)
    MongoPubsub.publish_async("rpc_client:#{data[1]}", {message: data})
  end

  # @param [Faye::WebSocket::Event] ws
  # @param [Array] data
  def handle_rpc_request(ws, data)
    client = client_for_ws(ws)
    if client
      @queue << [ws, client[:grid_id].to_s, data]
    end
  end

  # @param [Faye::WebSocket::Event] ws
  # @param [Array] data
  def handle_rpc_notification(ws, data)
    return if @queue.size > 800 # too busy to handle notifications

    client = client_for_ws(ws)
    if client
      @queue << [client[:grid_id].to_s, data]
    end
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
        Agent::NodeUnplugger.new(node).unplug!
        logger.info "node closed connection: #{node.name || node.node_id}"
      end
      @clients.delete(client)
    end
    ws.close
  rescue => exc
    logger.error "on_close: #{exc.message}"
    logger.error exc.backtrace.join("\n") if exc.backtrace
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

  # @param [String] agent_version
  # @return [Boolean]
  def valid_agent_version?(agent_version)
    Gem::Dependency.new('', "~> #{self.our_version}").match?('', agent_version)
  end

  # @return [String]
  def our_version
    major, minor, patch, extension = Server::VERSION.split('.')
    version = "#{major}.#{minor}.0"
    version << ".#{extension}" if extension
    version
  end

  # @param [Faye::WebSocket] ws
  # @param [HostNode] node
  def handle_invalid_agent_version(ws, node)
    node.set(connected: false, last_seen_at: Time.now.utc)
    EventMachine::Timer.new(1) do
      ws.close(4010) if ws
    end
  end

  # @param [Faye::Websocket] ws
  # @param [Array] message
  def send_message(ws, message)
    EM.next_tick {
      ws.send(MessagePack.dump(message).bytes)
    }
  end

  def subscribe_to_rpc_channel
    MongoPubsub.subscribe('rpc_client') do |message|
      if message && message.is_a?(Hash) && RPC_MSG_TYPES.include?(message['type'].to_s)
        self.on_rpc_message(message)
      end
    end
  end

  # @param [Hash] msg
  def on_rpc_message(msg)
    client = client_for_id(msg['id'])
    if client
      self.send_message(client[:ws], msg['message'])
    end
  rescue => exc
    logger.error "on_rpc_message: #{exc.message}"
  end

  def watch_connections
    Thread.new {
      sleep 1 until EM.reactor_running?
      EM::PeriodicTimer.new(KEEPALIVE_TIME) do
        @clients.each do |client|
          self.verify_client_connection(client)
        end
      end
    }
  end

  # @param [Hash] client
  def verify_client_connection(client)
    timer = EM::Timer.new(5) do
      self.on_close(client[:ws])
    end
    client[:ws].ping {
      timer.cancel
      self.on_pong(client)
    }
  end

  # @param [Hash] client
  def on_pong(client)
    node = HostNode.find_by(node_id: client[:id])
    if node
      if node.connected?
        node.set(last_seen_at: Time.now.utc)
      else
        grid = Grid.find_by(node_id: client[:grid_id])
        Agent::NodePlugger.new(grid, node).plugin! if grid
      end
    else
      self.on_close(client[:ws])
    end
  end
end
