require 'kontena-websocket-client'
require 'base64'
require_relative './rpc_server'
require_relative '../logging'
require_relative '../../helpers/current_leader'

module Cloud
  class WebsocketClient
    include Celluloid
    include CurrentLeader
    include Logging

    CONNECT_INTERVAL = 5.0
    CONNECT_TIMEOUT = 10.0
    OPEN_TIMEOUT = 10.0
    PING_INTERVAL = 30.0 # seconds
    PING_TIMEOUT = Kernel::Float(ENV['WEBSOCKET_TIMEOUT'] || 5.0)
    CLOSE_TIMEOUT = 10.0
    WRITE_TIMEOUT = 10.0 # this one is a little odd

    attr_reader :rpc_server
    attr_reader :users

    ##
    # @param api_uri [String]
    # @param client_id [String]
    # @param client_secret [String]
    # @param ssl_params [Hash] default is to use ssl certificate validation
    # @param ssl_hostname [String]
    def initialize(api_uri, client_id: , client_secret:, ssl_params: {}, ssl_hostname: nil)
      @api_uri = api_uri
      @client_id = client_id
      @client_secret = client_secret
      @ssl_params = ssl_params
      @ssl_hostname = ssl_hostname

      raise "Cloud Socket URI not configured" if @api_uri.to_s.empty?

      @rpc_server = RpcServer.new
      @users = {}

      info "initialized with client ID #{@client_id} (secret #{@client_secret[0..8]}...)"

      @connected = false
      @connecting = false
    end

    # Called from CloudWebsocketConnectJob
    def start
      every(CONNECT_INTERVAL) do
        connect if !connected? unless connecting?
      end
    end

    # Called from CloudWebsocketConnectJob
    def stop
      @ws.close
      self.terminate # TODO: wait for close?
    end

    # @return [Boolean]
    def connected?
      @connected
    end

    # @return [Boolean]
    def connecting?
      @connecting
    end

    # @return [String]
    def authorization_token
      Base64.urlsafe_encode64(@client_id+':'+@client_secret)
    end

    def connect
      @connecting = true

      info "Connecting to cloud at #{@api_uri}"

      headers = {
        'Authorization' => "Basic #{authorization_token}"
      }
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
        # blocks until open, raises on errors
        ws.connect

        # These are called from the read_ws -> defer thread, proxy back to actor
        actor.on_open

        ws.read do |message|
          actor.on_message(message)
        end
      }

    rescue Kontena::Websocket::CloseError => exc
      # handle known errors, will reconnect
      on_close(exc.code, exc.reason)

    rescue Kontena::Websocket::Error => exc
      # handle known errors, will reconnect
      on_close(1006, exc.message)

    rescue => exc
      # TODO: crash instead of reconnecting on unknown errors?
      error exc
      on_close(1006, exc.message)

    else
      # client closed, not going to happen
      on_close(ws.close_code, ws.close_reason)

    ensure
      @ws = nil

      ws.disconnect
    end

    def on_open
      @connected = true
      @connecting = false

      begin
        ssl_cert = @ws.ssl_cert!
      rescue Kontena::Websocket::SSLVerifyError => ssl_error
        ssl_cert = ssl_error.cert
      else
        ssl_error = nil
      end

      ssl_verify = @ws.ssl_verify?

      if ssl_cert && ssl_error
        warn "Connected to #{@ws.url} with ssl errors: #{ssl_error} (subject #{ssl_cert.subject}, issuer #{ssl_cert.issuer})"
      elsif ssl_error
        warn "Connected to #{@ws.url} with ssl errors: #{ssl_error}"
      elsif ssl_cert && !ssl_verify
        warn "Connected to #{@ws.url} without ssl verify: #{ssl_cert.subject} (issuer #{ssl_cert.issuer})"
      elsif ssl_cert
        info "Connected to #{@ws.url} with ssl verify: #{ssl_cert.subject} (issuer #{ssl_cert.issuer})"
      else
        info "Connected to #{@ws.url} without ssl"
      end

      subscribe_events
    end

    # @param [String, Array] msg
    def on_message(msg)
      unless leader?
        debug "Ignoring request because not leader"
        return
      end

      data = MessagePack.unpack(msg.pack('c*'))

      if request_message?(data)
        debug "RPC request #{data[2]}"
        response = rpc_server.handle_request(data)
        send_message(MessagePack.dump(response).bytes)
      elsif notification_message?(data)
        debug "RPC notification #{data[2]}"
        rpc_server.handle_notification(data)
      else
        warn "Unknown RPC: #{data}"
      end
    rescue => exc
      error exc
    end

    # @param code [Integer]
    # @param reason [String]
    def on_close(code, reason)
      @connected = false
      @connecting = false

      case code
      when 1002
        error 'cloud does not accept our access token'
      else
        info "cloud connection closed with code #{code}: #{reason}"
      end

      unsubscribe_events
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

    # @raise [RuntimeError] not connected
    # @return [Kontena::Websocket::Client]
    def ws
      fail "not connected" unless @ws
      @ws
    end

    ##
    # @param [String, Array] msg
    def send_message(msg)
      ws.send(msg)
    rescue => exc
      warn "failed to send message: #{exc.message}"
    end

    # @param [Hash] msg
    def send_notification_message(msg)
      invalidate_users_cache if msg[:type] == 'User' # clear cache if users are modified
      grid_id = resolve_grid_id(msg)
      users = resolve_users(grid_id)
      params = [grid_id, users, msg[:object]]
      message = [2, "#{msg[:type]}##{msg[:event]}", params]
      debug "Send notify #{message[1]}"
      send_message(MessagePack.dump(message).bytes)
    end

    def resolve_grid_id(msg)
      object = msg[:object]
      if msg[:type] == "Grid"
        object['id']
      else
        object.dig('grid', 'id')
      end
    end

    def resolve_users(grid_id)
      if grid_id
        return users[grid_id] if users[grid_id] # Found from cache
        grid = Grid.find_by(name: grid_id)
        grid_users = (User.master_admins + grid.users).uniq
        users[grid_id] = grid_users.map{|u| u.external_id}.compact
      else
        User.master_admins.map{|u| u.external_id}.compact
      end
    end

    def invalidate_users_cache
      debug 'invalidate user cache'
      @users = {}
    end

    # @param [String] channel
    def subscribe_events(channel = EventStream.channel)
      actor = Actor.current

      @subscription = MongoPubsub.subscribe(channel) do |message|
        if leader?
          actor.send_notification_message(message)
        end
      end
      @subscription
    end

    def unsubscribe_events
      MongoPubsub.unsubscribe(@subscription) if @subscription
    end
  end
end
