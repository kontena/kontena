require 'faye/websocket'
require 'eventmachine'
require 'base64'
require_relative '../logging'
require_relative './rpc_server'
require_relative '../../helpers/current_leader'

module Faye::WebSocket::Client::Connection
  # Workaround https://github.com/faye/faye-websocket-ruby/issues/103
  # force connection to close without waiting if the send buffer is full
  def close_connection_after_writing
    close_connection
  end
end

module Cloud
  class WebsocketClient
    include CurrentLeader
    class Config
      attr_accessor :api_uri
      def initialize
        @api_uri = nil
      end
    end

    def self.configure(&block)
      config = Config.new
      yield config
      @@api_uri = config.api_uri
    end

    def self.api_uri
      @@api_uri
    end

    include Logging
    KEEPALIVE_TIME = 30


    @@api_uri
    attr_reader :api_uri,
                :client_id,
                :client_secret,
                :ws,
                :rpc_server,
                :ping_timer,
                :users

    delegate :on, to: :ws


    ##
    # @param [String] api_uri
    # @param [String] client_id
    # @param [String] client_secret
    def initialize(client_id, client_secret)
      @api_uri = self.class.api_uri
      @client_id = client_id
      @client_secret = client_secret
      @rpc_server = RpcServer.new
      @connected = false
      @connecting = false
      @ping_timer = nil
      @users = {}
    end

    def ensure_connect
      @connect_timer = EM::PeriodicTimer.new(5) {
        connect unless connected?
      }
      @connect_verify_timer = EM::PeriodicTimer.new(KEEPALIVE_TIME) {
        if connected?
          EM.next_tick { verify_connection }
        end
      }
    end

    def disconnect
      @connect_timer.cancel
      @connect_verify_timer.cancel
      close
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
      if self.api_uri.to_s.empty?
        error "Cloud Socket URI not configured"
        return
      end
      @connected = false
      @connecting = true
      headers = {
        'Authorization' => "Basic #{Base64.urlsafe_encode64(self.client_id+':'+self.client_secret)}"
      }
      @ws = Faye::WebSocket::Client.new("#{self.api_uri}/platform", nil, { headers: headers })

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
        error "cloud connection closed with error: #{event.message}"
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

    # @param [Faye::WebSocket::API::Event] event
    def on_open(event)
      ping_timer.cancel if ping_timer
      info "cloud connection opened to #{self.api_uri}"
      subscribe_events(EventStream.channel)
      @connected = true
      @connecting = false
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_message(event)
      debug "Received websocket message"
      if leader?
        data = MessagePack.unpack(event.data.pack('c*'))
        EM.defer {
          if request_message?(data)
            debug "Creating RPC request"
            response = rpc_server.handle_request(data)
            send_message(MessagePack.dump(response).bytes)
          elsif notification_message?(data)
            rpc_server.handle_notification(data)
          end
        }
      else
        debug "Ignoring request because not leader"
      end
    rescue => exc
      error exc.message
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_close(event)
      @ping_timer = nil
      @connected = false
      @connecting = false
      @ws = nil
      if event.code == 1002
        handle_invalid_token
      end
      info "cloud connection closed with code: #{event.code}"
      unsubscribe_events
    rescue => exc
      error exc.message
    end

    # @param [Hash] msg
    def send_notification_message(msg)
      invalidate_users_cache if msg['type'] == 'User' # clear cache if users are modified
      grid_id = resolve_grid_id(msg)
      users = resolve_users(grid_id)
      params = [grid_id, users, msg['object']]
      message = [2, "#{msg['type']}##{msg['event']}", params]
      debug "Sending notification message: #{message}"
      send_message(MessagePack.dump(message).bytes)
    rescue => exc
      error exc.message
    end

    def resolve_grid_id(msg)
      object = msg['object']
      if msg['type'] == "Grid"
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

    # @param [String] channel
    def subscribe_events(channel)
      @subscription = MongoPubsub.subscribe(channel) do |message|
        if leader?
          send_notification_message(message)
        end
      end
      @subscription
    end

    def unsubscribe_events
      MongoPubsub.unsubscribe(@subscription) if @subscription
    end

    def handle_invalid_token
      error 'cloud does not accept our access token'
    end

    # @param [Array] msg
    # @return [Boolean]
    def request_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 0
    end

    def invalidate_users_cache
      debug 'invalidate user cache'
      @users = {}
    end

    # @param [Array] msg
    # @return [Boolean]
    def notification_message?(msg)
      msg.is_a?(Array) && msg.size == 3 && msg[0] == 2
    end

    def verify_connection
      return unless @ping_timer.nil?

      @ping_timer = EM::Timer.new(2) do
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

    def close
      ws.close
    end
  end
end
