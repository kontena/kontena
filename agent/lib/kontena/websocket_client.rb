require 'msgpack'
require_relative 'logging'
require_relative 'rpc_server'
require_relative 'rpc_client'

# Celluloid::Notifications:
#   websocket:connect [nil] connecting, not yet connected
#   websocket:open [nil] connected, websocket open
#   websocket:connected [nil] received /agent/master_info from server
#   websocket:disconnected [nil] websocket disconnected
module Kontena
  class WebsocketClient
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    STRFTIME = '%F %T.%NZ'

    CONNECT_INTERVAL = 1.0
    CONNECT_TIMEOUT = 10.0
    OPEN_TIMEOUT = 10.0
    PING_INTERVAL = 30.0 # seconds
    PING_TIMEOUT = Kernel::Float(ENV['WEBSOCKET_TIMEOUT'] || 5.0)
    CLOSE_TIMEOUT = 10.0
    WRITE_TIMEOUT = 10.0 # this one is a little odd

    # @param [String] api_uri
    # @param [String] node_id
    # @param [String] node_name
    # @param [String] grid_token
    # @param [String] node_token
    # @param [Array<String>] node_labels
    # @param [Hash] ssl_params
    # @param [String] ssl_hostname
      def initialize(api_uri, node_id, node_name:, grid_token: nil, node_token: nil, node_labels: [], ssl_params: {}, ssl_hostname: nil, autostart: true)
      @api_uri = api_uri
      @node_id = node_id
      @node_name = node_name
      @grid_token = grid_token
      @node_token = node_token
      @node_labels = node_labels
      @ssl_params = ssl_params
      @ssl_hostname = ssl_hostname

      @connected = false
      @connecting = false

      if @node_token
        info "initialized with node token #{@node_token[0..8]}..., node ID #{@node_id}"
      elsif @grid_token
        info "initialized with grid token #{@grid_token[0..8]}..., node ID #{@node_id}"
      else
        fail "Missing grid, node token"
      end

      async.start if autostart
    end

    # @return [Boolean]
    def connected?
      @connected
    end

    # @return [Boolean]
    def connecting?
      @connecting
    end

    def rpc_server
      Celluloid::Actor[:rpc_server]
    end
    def rpc_client
      Celluloid::Actor[:rpc_client]
    end

    def start
      every(CONNECT_INTERVAL) do
        connect! if !connected? unless connecting?
      end
    end

    def connect!
      @connecting = true

      info "connecting to master at #{@api_uri}"
      headers = {
          'Kontena-Node-Id' => @node_id.to_s,
          'Kontena-Node-Name' => @node_name,
          'Kontena-Version' => Kontena::Agent::VERSION,
          'Kontena-Node-Labels' => @node_labels.join(','),
          'Kontena-Connected-At' => Time.now.utc.strftime(STRFTIME),
      }

      if @node_token
        headers['Kontena-Node-Token'] = @node_token.to_s
      elsif @grid_token
        headers['Kontena-Grid-Token'] = @grid_token.to_s
      else
        fail "Missing grid, node token"
      end

      @ws = Kontena::Websocket::Client.new(@api_uri,
        headers: headers,
        ssl_params: @ssl_params,
        ssl_hostname: @ssl_hostname,
        connect_timeout: CONNECT_TIMEOUT,
        open_timeout: OPEN_TIMEOUT,
        ping_interval: PING_INTERVAL,
        ping_timeout: PING_TIMEOUT,
        close_timeout: CLOSE_TIMEOUT,
      )

      async.connect_client @ws

      publish('websocket:connect', nil)

    rescue => exc
      error exc

      # abort connect, allow re-connecting
      @connecting = false
    end

    # Connect the websocket client, and read messages.
    #
    # Keeps running as a separate defer thread as long as the websocket client is connected.
    #
    # @param ws [Kontena::Websocket::Client]
    def connect_client(ws)
      actor = Actor.current

      # run the blocking websocket client connect+read in a separate thread
      defer {
        ws.on_pong do |delay|
          # XXX: called with the client mutex locked, do not block
          actor.async.on_pong(delay)
        end

        # blocks until open, raises on errors
        ws.connect

        # These are called from the read_ws -> defer thread, proxy back to actor
        actor.on_open

        ws.read do |message|
          actor.on_message(message)
        end
      }

    rescue Kontena::Websocket::CloseError => exc
      # server closed connection
      on_close(exc.code, exc.reason)

    rescue Kontena::Websocket::Error => exc
      # handle known errors, will reconnect or shutdown
      on_error exc

    rescue => exc
      # XXX: crash instead of reconnecting on unknown errors?
      error exc

    else
      # impossible: agent closed connection?!
      info "Agent closed connection with code #{ws.close_code}: #{ws.close_reason}"

    ensure
      disconnected!
      ws.disconnect # close socket
    end

    # Websocket handshake complete.
    def on_open
      ssl_verify = ws.ssl_verify?

      begin
        ssl_cert = ws.ssl_cert!
        ssl_error = nil
      rescue Kontena::Websocket::SSLVerifyError => exc
        ssl_cert = exc.cert
        ssl_error = exc
      end

      if ssl_error
        if ssl_cert
          warn "insecure connection established with SSL errors: #{ssl_error}: #{ssl_cert.subject} (issuer #{ssl_cert.issuer})"
        else
          warn "insecure connection established with SSL errors: #{ssl_error}"
        end
      elsif ssl_cert
        if !ssl_verify
          warn "secure connection established without KONTENA_SSL_VERIFY=true: #{ssl_cert.subject} (issuer #{ssl_cert.issuer})"
        else
          info "secure connection established with KONTENA_SSL_VERIFY: #{ssl_cert.subject} (issuer #{ssl_cert.issuer})"
        end
      else
        info "unsecure connection established without SSL"
      end

      connected!
    end

    # The websocket is connected: @ws is now valid and wen can send message
    def connected!
      @connected = true
      @connecting = false

      # NOTE: the server may still reject the websocket connection by closing it after the open handshake
      #       wait for the /agent/master_info RPC before emitting websocket:connected
      publish('websocket:open', nil)
    end

    def ws
      fail "not connected" unless @ws

      @ws
    end

    # The websocket is disconnected: @ws is invalid and we can no longer send messages
    def disconnected!
      @ws = nil # prevent further send_message calls until reconnected
      @connected = false
      @connecting = false

      # any queued up send_message calls will fail
      publish('websocket:disconnected', nil)
    end

    # Called from RpcServer, does not crash the Actor on errors.
    #
    # @param [String, Array] msg
    # @raise [RuntimeError] not connected
    def send_message(msg)
      ws.send(msg)
    rescue => exc
      warn exc
      abort exc
    end

    # Called from RpcClient, does not crash the Actor on errors.
    #
    # @param [String] method
    # @param [Array] params
    # @raise [RuntimeError] not connected
    def send_notification(method, params)
      data = MessagePack.dump([2, method, params]).bytes
      ws.send(data)
    rescue => exc
      warn exc
      abort exc
    end

    # Called from RpcClient, does not crash the Actor on errors.
    #
    # @param [Integer] id
    # @param [String] method
    # @param [Array] params
    # @raise [RuntimeError] not connected
    def send_request(id, method, params)
      data = MessagePack.dump([0, id, method, params]).bytes
      ws.send(data)
    rescue => exc
      warn exc
      abort exc
    end

    # @param [String] message
    def on_message(message)
      data = MessagePack.unpack(message.pack('c*'))
      if request_message?(data)
        rpc_server.async.handle_request(Actor.current, data)
      elsif response_message?(data)
        rpc_client.async.handle_response(data)
      elsif notification_message?(data)
        rpc_server.async.handle_notification(data)
      end
    end

    # Websocket connection failed
    #
    # @param exc [Kontena::Websocket::Error]
    def on_error(exc)
      case exc
      when Kontena::Websocket::SSLVerifyError
        if exc.cert
          error "unable to connect to SSL server with KONTENA_SSL_VERIFY=true: #{exc} (subject #{exc.subject}, issuer #{exc.issuer})"
        else
          error "unable to connect to SSL server with KONTENA_SSL_VERIFY=true: #{exc}"
        end

      when Kontena::Websocket::SSLConnectError
        error "unable to connect to SSL server: #{exc}"

      when Kontena::Websocket::ConnectError
        error "unable to connect to server: #{exc}"

      when Kontena::Websocket::ProtocolError
        error "unexpected response from server, check url: #{exc}"

      else
        error "websocket error: #{exc}"
      end
    end

    # Server closed websocket connection
    #
    # @param code [Integer]
    # @param reason [String]
    def on_close(code, reason)
      debug "Server closed connection with code #{code}: #{reason}"

      case code
      when 4001
        handle_invalid_token
      when 4010
        handle_invalid_version(reason)
      when 4040, 4041
        handle_invalid_connection(reason)
      else
        warn "connection closed with code #{code}: #{reason}"
      end
    end

    def handle_invalid_token
      error 'master does not accept our token, shutting down ...'
      Kontena::Agent.shutdown
    end

    def handle_invalid_version(reason)
      agent_version = Kontena::Agent::VERSION
      error "master does not accept our version (#{agent_version}): #{reason}"
      Kontena::Agent.shutdown
    end

    def handle_invalid_connection(reason)
      error "master indicates that this agent should not reconnect: #{reason}"
      Kontena::Agent.shutdown
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

    # @param delay [Float]
    def on_pong(delay)
      if delay > PING_TIMEOUT / 2
        warn "server ping %.2fs of %.2fs timeout" % [delay, PING_TIMEOUT]
      else
        debug "server ping %.2fs of %.2fs timeout" % [delay, PING_TIMEOUT]
      end
    end
  end
end
