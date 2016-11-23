require 'faye/websocket'
require 'eventmachine'
require 'base64'
require_relative '../logging'
require_relative './rpc_server'

module Cloud
  class WebsocketClient
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
                :ping_timer

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
      self.ws.close if self.ws
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
      @connected = true
      @connecting = false
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_message(event)
      data = MessagePack.unpack(event.data.pack('c*'))
      if request_message?(data)
        EM.defer {
          response = rpc_server.handle_request(data)
          send_message(MessagePack.dump(response).bytes)
        }
      elsif notification_message?(data)
        EM.defer {
          rpc_server.handle_notification(data)
        }
      end
    rescue => exc
      error exc.message
    end

    # @param [Faye::WebSocket::API::Event] event
    def on_close(event)
      @connected = false
      @connecting = false
      @ws = nil
      if event.code == 1002
        handle_invalid_token
      end
      info "cloud connection closed with code: #{event.code}"
    rescue => exc
      error exc.message
    end

    def handle_invalid_token
      error 'cloud does not accept our access token'
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

    def verify_connection
      return unless @ping_timer.nil?

      @ping_timer = EM::Timer.new(2) do
        if @connected
          info 'did not receive pong, closing connection'
          ws.close(1000)
        end
      end
      ws.ping {
        @ping_timer.cancel
        @ping_timer = nil
      }
    rescue => exc
      error exc.message
    end
  end
end
