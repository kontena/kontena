require 'msgpack'
require_relative 'logging'
require_relative 'rpc_server'
require_relative 'rpc_client'

module Faye::WebSocket::Client::Connection
  # Workaround https://github.com/faye/faye-websocket-ruby/issues/103
  # force connection to close without waiting if the send buffer is full
  def close_connection_after_writing
    close_connection
  end
end

module Kontena
  class WebsocketClient
    include Kontena::Logging

    KEEPALIVE_INTERVAL = 30.0 # seconds
    PING_TIMEOUT = 5.0 # seconds

    attr_reader :api_uri,
                :api_token,
                :ws,
                :rpc_server,
                :ping_timer

    delegate :on, to: :ws

    # @param [String] api_uri
    # @param [String] api_token
    def initialize(api_uri, api_token)
      @api_uri = api_uri
      @api_token = api_token
      @rpc_server = Kontena::RpcServer.pool
      @rpc_client = Kontena::RpcClient.supervise(as: :rpc_client, args: [self])
      @abort = false
      @connected = false
      @connecting = false
      @ping_timer = nil
      info "initialized with token #{@api_token[0..10]}..."
    end

    def ensure_connect
      EM::PeriodicTimer.new(1) {
        connect unless connected?
      }
      EM::PeriodicTimer.new(KEEPALIVE_INTERVAL) {
        if connected?
          EM.next_tick { verify_connection }
        end
      }
    end

    # @return [Boolean]
    def connected?
      @connected
    end

    # @return [Boolean]
    def connecting?
      @connecting
    end

    def connect
      return if connecting?
      @connected = false
      @connecting = true
      info "connecting to master at #{api_uri}"
      headers = {
          'Kontena-Grid-Token' => self.api_token.to_s,
          'Kontena-Node-Id' => host_id.to_s,
          'Kontena-Version' => Kontena::Agent::VERSION,
          'Kontena-Node-Labels' => labels
      }
      @ws = Faye::WebSocket::Client.new(self.api_uri, nil, {headers: headers})

      notify_actors('websocket:connect', self)

      @ws.on :open do |event|
        on_open(event)
      end
      @ws.on :message do |event|
        on_message(event)
      end
      @ws.on :close do |event|
        on_close(event)
      end
      @ws.on :error do |event|
        on_error(event)
      end
    end

    ##
    # @param [String, Array] msg
    def send_message(msg)
      EM.next_tick {
        begin
          @ws.send(msg) if @ws
        rescue
          error "failed to send message"
        end
      }
    rescue => exc
      error "failed to send message: #{exc.message}"
    end

    # @param [String] method
    # @param [Array] params
    def send_notification(method, params)
      data = MessagePack.dump([2, method, params]).bytes
      send_message(data)
    rescue => exc
      error "failed to send notification: #{exc.message}"
    end

    # @param [Integer] id
    # @param [String] method
    # @param [Array] params
    def send_request(id, method, params)
      data = MessagePack.dump([0, id, method, params]).bytes
      send_message(data)
    rescue => exc
      error "failed to send request: #{exc.message}"
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_open(event)
      ping_timer.cancel if ping_timer
      info 'connection established'
      @connected = true
      @connecting = false
      notify_actors('websocket:open', event)
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_message(event)
      data = MessagePack.unpack(event.data.pack('c*'))
      if request_message?(data)
        rpc_server.async.handle_request(self, data)
      elsif response_message?(data)
        Celluloid::Actor[:rpc_client].async.handle_response(data)
      elsif notification_message?(data)
        rpc_server.async.handle_notification(data)
      end
    rescue => exc
      error exc.message
    end

    def on_error(event)
      debug event.message.inspect

      if event.message == Errno::EINVAL
        error "invalid URI: #{api_uri}"
      elsif event.message == Errno::ECONNREFUSED
        error "connection refused: #{api_uri}"
      elsif event.message == Errno::EPROTO
        error "protocol error, check ws/wss: #{api_uri}"
      else
        error "connection error: #{event.message}"
      end
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_close(event)
      @ping_timer = nil
      @connected = false
      @connecting = false
      @ws = nil
      if event.code == 4001
        handle_invalid_token
      elsif event.code == 4010
        handle_invalid_version
      end
      info "connection closed with code #{event.code}"
      notify_actors('websocket:close', nil)
    rescue => exc
      error exc.message
    end

    def handle_invalid_token
      error 'master does not accept our token, shutting down ...'
      EM.next_tick { abort('Shutting down ...') }
    end

    def handle_invalid_version
      agent_version = Kontena::Agent::VERSION
      error "master does not accept our version (#{agent_version}), shutting down ..."
      EM.next_tick { abort("Shutting down ...") }
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
      @ping_timer = EM::Timer.new(PING_TIMEOUT) do
        delay = Time.now - ping_time

        # @ping_timer remains nil until re-connected to prevent further keepalives while closing
        if @connected
          error 'keepalive ping %.2fs timeout, closing connection' % [delay]
          close
        end
      end
      ws.ping {
        @ping_timer.cancel
        @ping_timer = nil

        delay = Time.now - ping_time

        if delay > PING_TIMEOUT / 2
          warn "keepalive ping %.2fs of %.2fs timeout" % [delay, PING_TIMEOUT]
        else
          debug "keepalive ping %.2fs of %.2fs timeout" % [delay, PING_TIMEOUT]
        end
      }
    rescue => exc
      error exc.message
    end

    # Abort the connection, closing the websocket, with a timeout
    def close
      # stop sending messages, queue them up until reconnected
      notify_actors('websocket:disconnect', nil)

      # send close frame; this has a 30s timeout
      ws.close
    end

    def notify_actors(event, value)
      Celluloid::Notifications.publish(event, value)
    end
  end
end
