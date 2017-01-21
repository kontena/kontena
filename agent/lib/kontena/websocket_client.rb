require_relative 'logging'
require_relative 'rpc_server'

module Kontena
  class WebsocketClient
    include Kontena::Logging

    KEEPALIVE_TIME = 30

    if defined? Faye::Websocket::Client.CLOSE_TIMEOUT
      # use a slightly longer timeout as a fallback
      CLOSE_TIMEOUT = Faye::Websocket::Client.CLOSE_TIMEOUT + 5
    else
      CLOSE_TIMEOUT = 30
    end

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
      @abort = false
      @connected = false
      @connecting = false
      @ping_timer = nil
      @close_timer = nil
      info "initialized with token #{@api_token[0..10]}..."
    end

    def ensure_connect
      EM::PeriodicTimer.new(1) {
        connect unless connected?
      }
      EM::PeriodicTimer.new(KEEPALIVE_TIME) {
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
        error "connection closed with error: #{event.message}"
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
      elsif notification_message?(data)
        rpc_server.async.handle_notification(data)
      end
    rescue => exc
      error exc.message
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_close(event)
      @ping_timer = nil
      @close_timer.cancel if @close_timer
      @close_timer = nil
      @connected = false
      @connecting = false
      @ws = nil
      if event.code == 4001
        handle_invalid_token
      elsif event.code == 4010
        handle_invalid_version
      end
      info "connection closed with code: #{event.code}"
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

    # @return [String]
    def host_id
      Docker.info['ID']
    end

    # @return [Array<String>]
    def labels
      Docker.info['Labels'].to_a.join(',')
    end

    def verify_connection
      return unless @ping_timer.nil?

      @ping_timer = EM::Timer.new(2) do
        # @ping_timer remains nil until re-connected to prevent further keepalives while closing
        if @connected
          info 'did not receive pong, closing connection'
          close
        end
      end
      ws.ping {
        @ping_timer.cancel
        @ping_timer = nil
      }
    rescue => exc
      error exc.message
    end

    # Abort the connection, closing the websocket, with a timeout
    def close
      return if @close_timer

      # stop sending messages, queue them up until reconnected
      notify_actors('websocket:disconnect', nil)

      # send close frame; this will get stuck if the server is not replying
      ws.close(1000)

      @close_timer = EM::Timer.new(CLOSE_TIMEOUT) do
        if ws
          warn "Hit close timeout, abandoning existing websocket connection"

          # ignore events from the abandoned connection
          ws.remove_all_listeners

          # fake it
          on_close Faye::WebSocket::Event.create('close', :code => 1006, :reason => "Close timeout")
        end
      end
    end

    def notify_actors(event, value)
      Celluloid::Notifications.publish(event, value)
    end
  end
end
