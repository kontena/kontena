require 'faye/websocket'
require_relative '../services/rpc_server'
require_relative '../services/watchdog'
require_relative '../services/agent/node_plugger'
require_relative '../services/agent/node_unplugger'

class WebsocketBackend
  WATCHDOG_INTERVAL = 0.5.seconds
  WATCHDOG_THRESHOLD = 1.0.seconds
  WATCHDOG_TIMEOUT = 60.0.seconds

  STRFTIME = '%F %T.%NZ'
  KEEPALIVE_TIME = 30.seconds
  PING_TIMEOUT = Kernel::Float(ENV['WEBSOCKET_TIMEOUT'] || 5.seconds)
  CLOCK_SKEW = Kernel::Float(ENV['KONTENA_CLOCK_SKEW'] || 1.seconds)

  RPC_MSG_TYPES = %w(request notify)
  QUEUE_SIZE = 1000
  QUEUE_WATCH_PERIOD = 60 # once in a minute
  QUEUE_DROP_NOTIFICATIONS_LIMIT = (QUEUE_SIZE * 0.8)

  class CloseError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
    end
  end

  attr_reader :logger

  def initialize(app)
    @app     = app
    @clients = []
    @logger = Logger.new(STDOUT)
    @logger.level = (ENV['LOG_LEVEL'] || Logger::INFO).to_i
    @logger.progname = 'WebsocketBackend'
    @msg_counter = 0
    @msg_dropped = 0
    @queue = SizedQueue.new(QUEUE_SIZE)
    @rpc_server = RpcServer.new(@queue)
    @rpc_server.async.process!
    subscribe_to_rpc_channel
    watch_connections
    watch_queue
    watchdog
  end

  def call(env)
    if env['REQUEST_PATH'] == '/' && Faye::WebSocket.websocket?(env)
      req = Rack::Request.new(env)
      ws = Faye::WebSocket.new(env, nil,
        headers: {
          'Kontena-Version' => Server::VERSION,
          'Kontena-Connected-At' => Time.now.utc.strftime(STRFTIME),
        },
      )

      ws.on :open do |event|
        self.on_open(ws, req)
      end

      ws.on :message do |event|
        self.on_message(ws, event)
      end

      ws.on :close do |event|
        self.on_close(ws, event.code, event.reason)
      end

      # Return async Rack response
      ws.rack_response
    else
      @app.call(env)
    end
  end

  # @param node_id [String] request header Kontena-Node-Id
  # @param grid_token [String] request header Kontena-Grid-Token
  # @param node_name [String] initialize name for new node
  # @param init_attrs [Hash] initialize attributes on new node
  # @raise [CloseError]
  # @return [HostNode] with node_id set
  def find_node_by_grid_token(node_id, grid_token, node_name:, **init_attrs)
    # check grid
    grid = Grid.find_by(token: grid_token.to_s)

    raise CloseError.new(4001), "Invalid grid token" unless grid

    node = grid.host_nodes.find_by(node_id: node_id)

    if !node
      node = grid.create_node!(node_name, ensure_unique_name: true,
        node_id: node_id, **init_attrs
      )

      logger.info "new node #{node} connected using grid token"

    elsif node.token
      raise CloseError.new(4005), "Invalid grid token, node was created using a node token"

    else
      logger.debug "node #{node} connected using grid token"
    end

    return node
  end

  # @param node_id [String] request header Kontena-Node-Id
  # @param node_token [String] request header Kontena-Node-Token
  # @param init_attrs [Hash] initialize attributes on new node
  # @raise [CloseError]
  # @return [HostNode] with node_id set
  def find_node_by_node_token(node_id, node_token, init_attrs)
    node = HostNode.find_by(token: node_token.to_s)

    raise CloseError.new(4002), "Invalid node token" unless node

    node_by_id = HostNode.find_by(node_id: node_id)

    if !node_by_id
      # atomically initialize the node_id
      created_node = HostNode.where(:id => node.id, :node_id => nil)
        .find_one_and_update(:$set => {node_id: node_id, **init_attrs})

      if created_node
        logger.info "new node #{node} connected using node token with node_id #{node_id}"

        node.reload

      else
        logger.warn "new node #{node} connected using node token with node_id #{node_id}, but the node token was already used by #{node} with node ID #{node.node_id}"

        raise CloseError.new(4003), "Invalid node token, already used by a different node"
      end

    elsif node.id == node_by_id.id
      logger.debug "node #{node} connected using node token with node_id #{node_id}"

    else
      logger.warn "node #{node} connected using node token with node_id #{node_id}, but that node ID already exists for #{node_by_id}"

      raise CloseError.new(4006), "Invalid node ID, already used by a different node"
    end

    return node
  end

  # Authenticate and lookup HostNode for websocket connection
  #
  # @param [Rack::Request] req
  # @raise [CloseError]
  # @return [HostNode]
  def find_node(req)
    node_id = req.env['HTTP_KONTENA_NODE_ID']
    node_name = req.env['HTTP_KONTENA_NODE_NAME']
    node_labels = req.env['HTTP_KONTENA_NODE_LABELS'].to_s.split(',')
    init_attrs = {
      labels: req.env['HTTP_KONTENA_NODE_LABELS'].to_s.split(','),
      agent_version: req.env['HTTP_KONTENA_VERSION'].to_s,
    }

    if node_id.nil? || node_id.empty?
      raise CloseError.new(4000), "Missing Kontena-Node-ID"
    end
    if node_name.nil? || node_name.empty?
      raise CloseError.new(4000), "Missing Kontena-Node-Name"
    end

    if grid_token = req.env['HTTP_KONTENA_GRID_TOKEN']
      return find_node_by_grid_token(node_id, grid_token, node_name: node_name, **init_attrs)

    elsif node_token = req.env['HTTP_KONTENA_NODE_TOKEN']
      return find_node_by_node_token(node_id, node_token, init_attrs)

    else
      raise CloseError.new(4004), "Missing token"
    end
  end

  ##
  # On websocket connection open
  #
  # @param [Faye::WebSocket] ws
  # @param [Rack::Request] req
  def on_open(ws, req)
    node_id = req.env['HTTP_KONTENA_NODE_ID']
    connected_at = nil

    # check version
    agent_version = req.env['HTTP_KONTENA_VERSION'].to_s

    unless self.valid_agent_version?(agent_version)
      send_master_info(ws)
      raise CloseError.new(4010), "agent version #{agent_version} is not compatible with server version #{Server::VERSION}"
    end

    node = find_node(req)

    # check clock after version check, because older agent versions do not send this header
    connected_at = Time.parse(req.env['HTTP_KONTENA_CONNECTED_AT'])
    connected_dt = Time.now - connected_at

    if connected_dt > PING_TIMEOUT + CLOCK_SKEW
      raise CloseError.new(4020), "agent connected too far in the past, clock offset #{'%.2fs' % connected_dt} exceeds threshold"

    elsif connected_dt < -CLOCK_SKEW
      raise CloseError.new(4020), "agent connected too far in the future, clock offset #{'%.2fs' % connected_dt} exceeds threshold"
    end

    # connect
    logger.info "node #{node} agent version #{agent_version} connected at #{connected_at}, #{'%.2fs' % connected_dt} ago"

    client = {
        ws: ws,
        id: node.node_id.to_s,
        node_id: node.id,
        grid_id: node.grid.id,
        created_at: Time.now,
        connected_at: connected_at,
    }
    @clients << client

    send_master_info(ws)

    EM.defer { Agent::NodePlugger.new(node).plugin! connected_at }

  rescue CloseError => exc
    logger.warn "reject websocket connection for node #{node || node_id || '<nil>'}: #{exc}"
    ws.close(exc.code, exc.message)

    if !connected_at || connected_at > Time.now.utc
      # override invalid agent timestamp, as this would prevent the agent from later reconnecting with the correct timestamp
      connected_at = Time.now.utc
    end

    if node
      # this only applies to the clock skew errors, not any of the early token -> node or version errors
      Agent::NodePlugger.new(node).reject!(connected_at, exc.code, exc.message)
    end

  rescue => exc
    logger.error exc
  end

  ##
  # @param [Faye::WebSocket] ws
  # @param [Faye::WebSocket::Event] event
  def on_message(ws, event)
    data = MessagePack.unpack(event.data.pack('c*'))
    @msg_counter += 1
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
    if @queue.size > QUEUE_DROP_NOTIFICATIONS_LIMIT # too busy to handle notifications
      @msg_dropped += 1
      return
    end

    client = client_for_ws(ws)
    if client
      @queue << [client[:grid_id].to_s, data]
    end
  end

  # Unplug client on websocket connection close.
  #
  # The client may have already been unplugged, if we closed the connection.
  #
  # @param [Faye::WebSocket] ws
  # @param [Integer] code
  # @param [String] reason
  def on_close(ws, code, reason)
    client = @clients.find{|c| c[:ws] == ws}
    if client
      logger.info "node #{client[:id]} connection closed with code #{code}: #{reason}"
      unplug_client(client, code, reason)
    else
      logger.debug "ignore close of unplugged client with code #{code}: #{reason}"
    end
  rescue => exc
    logger.error exc
  end

  # Mark client HostNode as disconnected, and remove from @clients.
  #
  # The websocket connection may still be open and get closed later.
  # The client HostNode may not exist anymore.
  #
  # @param [Hash] client
  def unplug_client(client, code, reason)
    node = HostNode.find_by(id: client[:node_id])
    if node
      Agent::NodeUnplugger.new(node).unplug!(client[:connected_at], code, reason)
    else
      logger.warn "skip unplug of missing node #{client[:id]}"
    end
    @clients.delete(client)
  end

  ##
  # @param [Faye::WebSocket] ws
  # @return [Hash,NilClass]
  def client_for_ws(ws)
    @clients.find{ |c| c[:ws] == ws }
  end

  ##
  # @param [String] id
  # @return [Hash,NilClass]
  def client_for_id(id)
    @clients.find{ |c| c[:id] == id }
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

  # Send master_info RPC notification directly, without looping through the normal RPC mechanisms
  #
  # @param [Faye::Websocket] ws
  def send_master_info(ws)
    # symbols in RPC parameters are implicitly converted into strings by MongoPubsub
    send_rpc_notify(ws, '/agent/master_info', {'version' => Server::VERSION})
  end

  # @param [Faye::Websocket] ws
  def send_rpc_notify(ws, method, *params)
    send_message(ws, [2, method, params])
  end

  # Must be called in EM thread.
  #
  # @param [Faye::Websocket] ws
  # @param [Array] message
  def send_message(ws, message)
    ws.send(MessagePack.dump(message).bytes)
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
    EM.next_tick{
      client = client_for_id(msg['id'])
      if client
        self.send_message(client[:ws], msg['message'])
      end
    }
  rescue => exc
    logger.error "on_rpc_message: #{exc.message}"
  end

  def watch_connections
    EM::PeriodicTimer.new(KEEPALIVE_TIME) do
      @clients.each do |client|
        self.verify_client_connection(client)
      end
    end
  end

  def watch_queue
    EM::PeriodicTimer.new(QUEUE_WATCH_PERIOD) do
      logger.warn "#{@queue.size} messages in queue" if @queue.size > QUEUE_DROP_NOTIFICATIONS_LIMIT
      logger.warn "#{@msg_dropped} dropped notifications" if @msg_dropped > 0
      logger.info "#{@msg_counter / QUEUE_WATCH_PERIOD} messages per second"
      @msg_counter = 0
      @msg_dropped = 0
    end
  end

  # Start a Watchdog actor, and ping it every interval.
  # It will log warnings and finally abort the EM thread if the timer does not get run on time.
  def watchdog
    EM.next_tick {
      # must be called within the EM thread
      @watchdog = Watchdog.new(self.class.name, Thread.current,
        interval: WATCHDOG_INTERVAL,
        threshold: WATCHDOG_THRESHOLD,
        timeout: WATCHDOG_TIMEOUT,
      )
    }

    EM::PeriodicTimer.new(WATCHDOG_INTERVAL) do
      @watchdog.async.ping
    end
  end

  # @param [Hash] client
  def verify_client_connection(client)
    ping_time = Time.now
    timer = EM::Timer.new(PING_TIMEOUT) do
      self.on_client_timeout(client, Time.now - ping_time)
    end
    client[:ws].ping {
      timer.cancel
      self.on_pong(client, Time.now - ping_time)
    }
  end

  # @param [Hash] client
  # @param [Integer] delay
  def on_client_timeout(client, delay)
    logger.warn "Close node %s connection after %.2fs timeout" % [client[:id], delay]
    close_client(client, 4030, "ping timeout after %.2fs" % [delay])
  end

  # @param [Hash] client
  # @param [Integer] delay
  def on_pong(client, delay)
    if delay > PING_TIMEOUT / 2
      logger.warn "keepalive ping %.2fs of %.2fs timeout from client %s" % [delay, PING_TIMEOUT, client[:id]]
    else
      logger.debug { "keepalive ping %.2fs of %.2fs timeout from client %s" % [delay, PING_TIMEOUT, client[:id]] }
    end

    node = HostNode.find_by(id: client[:node_id])

    if node
      connected_node = HostNode.where(id: node.id, connected_at: client[:connected_at])
        .find_one_and_update({:$set => {last_seen_at: Time.now.utc}})

      if !connected_node
        logger.warn "Close conflicting connection for node #{node} connected at #{client[:connected_at]}, node has re-connected at #{node.connected_at}"
        close_client(client, 4041, "host node #{node} connection conflict with new connection at #{node.connected_at}")
      elsif !connected_node.connected
        logger.warn "Close connection of disconnected node #{node}"
        close_client(client, 4031, "host node #{node} has been disconnected")
      end
    else
      logger.warn "Close connection of removed node #{client[:id]}"
      close_client(client, 4040, "host node #{client[:id]} has been removed")
    end
  end

  # Unplug client, marking HostNode as disconnected, and close the websocket connection.
  #
  # @param [Hash] client
  def close_client(client, code, reason)
    # immediately remove from @clients and mark as disconnected
    unplug_client(client, code, reason)

    # triggers on :close later, or after 30s timeout, but the client will already be gone
    client[:ws].close(code, reason)
  end

  def stop_rpc_server
    Celluloid::Actor.kill(@rpc_server) if @rpc_server.alive?
  end
end
