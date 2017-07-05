require 'msgpack'
require_relative 'logging'
require_relative 'rpc_server'
require_relative 'rpc_client'

# Celluloid::Notifications:
#   websocket:connect [Kontena::WebsocketClient] connecting, not yet connected
#   websocket:open [Kontena::WebsocketClient] connected, websocket open
#   websocket:disconnect [Kontena::WebsocketClient] websocket closing
#   websocket:close [Kontena::WebsocketClient] websocket closed
module Kontena
  class WebsocketClient
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    STRFTIME = '%F %T.%NZ'
    KEEPALIVE_INTERVAL = 30.0 # seconds
    PING_TIMEOUT = Kernel::Float(ENV['WEBSOCKET_TIMEOUT'] || 5)

    attr_reader :api_uri,
                :ws,
                :rpc_server,
                :ping_timer

    # @param [String] api_uri
    # @param [String] grid_token
    # @param [String] node_token
    def initialize(api_uri, grid_token: nil, node_token: nil, autostart: true)
      @api_uri = api_uri
      @grid_token = grid_token
      @node_token = node_token

      @connected = false
      @connecting = false
      @ping_timer = nil

      if @node_token
        info "initialized with node token #{@node_token[0..8]}..., node ID #{host_id}"
      elsif @grid_token
        info "initialized with grid token #{@grid_token[0..8]}..., node ID #{host_id}"
      else
        fail "Missing grid, node token"
      end

      # XXX:
      @rpc_server = Kontena::RpcServer.supervise(as: :rpc_server)
      @rpc_client = Kontena::RpcClient.supervise(as: :rpc_client, args: [self])

      self.start if autostart
    end

    # @return [Boolean]
    def connected?
      @connected
    end

    # @return [Boolean]
    def connecting?
      @connecting
    end

    def start
      every(1.0) do
        connect if !connected? unless connecting?
      end

      every(KEEPALIVE_INTERVAL) do
        keepalive if connected?
      end
    end

    def connect
      info "connecting to master at #{api_uri}"
      headers = {
          'Kontena-Node-Id' => host_id.to_s,
          'Kontena-Version' => Kontena::Agent::VERSION,
          'Kontena-Node-Labels' => labels,
          'Kontena-Connected-At' => Time.now.utc.strftime(STRFTIME),
      }
      if @node_token
        headers['Kontena-Node-Token'] = @node_token.to_s
      elsif @grid_token
        headers['Kontena-Grid-Token'] = @grid_token.to_s
      else
        fail "Missing grid, node token"
      end

      @ws = Kontena::Websocket::Client.new(self.api_uri,
        headers: headers,
        ssl_verify: true,
      )

      # XXX: these should become async actor calls?
      @ws.on :open do |event|
        self.on_open(event)
      end
      @ws.on :message do |event|
        self.on_message(event)
      end
      @ws.on :close do |event|
        self.on_close(event)
      end
      @ws.on :error do |event|
        self.on_error(event)
      end

      ws.connect!

      # service the websocket reads, and emit events
      async.read_ws @ws

      @connecting = true

      publish('websocket:connect', self)
    end

    # @param ws [Kontena::Websocket::Client]
    def read_ws(ws)
      # run the blocking websocket client read in a separate thread
      # raises on errors, crashing the actor
      defer {
        ws.read
      }
    end

    ##
    # @param [String, Array] msg
    def send_message(msg)
      fail "not connected" unless @ws

      @ws.send(msg)
    end

    # @param [String] method
    # @param [Array] params
    def send_notification(method, params)
      data = MessagePack.dump([2, method, params]).bytes
      send_message(data)
    end

    # @param [Integer] id
    # @param [String] method
    # @param [Array] params
    def send_request(id, method, params)
      data = MessagePack.dump([0, id, method, params]).bytes
      send_message(data)
    end

    # @param [WebSocket::Driver::OpenEvent] event
    def on_open(event)
      ping_timer.cancel if ping_timer
      info 'connection established'
      @connected = true
      @connecting = false
      publish('websocket:open', self)
    end

    # @param [WebSocket::Driver::MessageEvent] event.data
    def on_message(event)
      data = MessagePack.unpack(event.data.pack('c*'))
      if request_message?(data)
        Celluloid::Actor[:rpc_server].async.handle_request(self, data)
      elsif response_message?(data)
        Celluloid::Actor[:rpc_client].async.handle_response(data)
      elsif notification_message?(data)
        Celluloid::Actor[:rpc_server].async.handle_notification(data)
      end
    end

    # @param [Exception]
    def on_error(exc)
      debug exc.inspect

      case exc
      when Errno::EINVAL
        error "invalid URI: #{api_uri}"
      when Errno::ECONNREFUSED
        error "connection refused: #{api_uri}"
      when Errno::EPROTO
        error "protocol error, check ws/wss: #{api_uri}"
      else
        error "connection error: #{event.message}"
      end
    end

    # @param [WebSocket::Driver::CloseEvent] event.code, event.reason
    def on_close(event)
      @ping_timer = nil
      @connected = false
      @connecting = false
      @ws = nil

      case event.code
      when 4001
        handle_invalid_token
      when 4010
        handle_invalid_version(event.reason)
      when 4040, 4041
        handle_invalid_connection(event.reason)
      else
        warn "connection closed with code #{event.code}: #{event.reason}"
      end
      publish('websocket:close', nil)
    end

    def handle_invalid_token
      error 'master does not accept our token, shutting down ...'
      Kernel.abort('Shutting down ...')
    end

    def handle_invalid_version(reason)
      agent_version = Kontena::Agent::VERSION
      error "master does not accept our version (#{agent_version}): #{reason}"
      Kernel.abort("Shutting down ...")
    end

    def handle_invalid_connection(reason)
      error "master indicates that this agent should not reconnect: #{reason}"
      Kernel.abort("Shutting down ...")
    end

    # @param [Array] msg
    # @return [Boolean]
    def request_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 0
    end

    # @param [Array] msg
    # @return [Boolean]
    def notification_message?(msg)
      msg.is_a?(Array) && msg.size == 3 && msg[0] == 2
    end

    # @param [Array] msg
    # @return [Boolean]
    def response_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 1
    end

    # @return [String]
    def host_id
      Docker.info['ID']
    end

    # @return [Array<String>]
    def labels
      Docker.info['Labels'].to_a.join(',')
    end

    def verify_connection
      return if @ping_timer

      ping_time = Time.now
      @ping_timer = after(PING_TIMEOUT) do
        delay = Time.now - ping_time

        # @ping_timer remains nil until re-connected to prevent further keepalives while closing
        if connected?
          error 'keepalive ping %.2fs timeout, closing connection' % [delay]
          close
        end
      end
      @ws.ping {
        @ping_timer.cancel
        @ping_timer = nil

        delay = Time.now - ping_time

        if delay > PING_TIMEOUT / 2
          warn "keepalive ping %.2fs of %.2fs timeout" % [delay, PING_TIMEOUT]
        else
          debug "keepalive ping %.2fs of %.2fs timeout" % [delay, PING_TIMEOUT]
        end
      }
    end

    # Abort the connection, closing the websocket, with a timeout
    def close
      # stop sending messages, queue them up until reconnected
      publish('websocket:disconnect', self)

      # send close frame; this has a 30s timeout
      @ws.close
    end
  end
end
