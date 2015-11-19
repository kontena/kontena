require 'cgi'
require 'socket'
require_relative 'logging'
require_relative 'rpc_server'

module Kontena
  class WebsocketClient
    include Kontena::Logging

    KEEPALIVE_TIME = 30

    attr_reader :api_uri, :api_token, :ws
    delegate :on, to: :ws

    ##
    # @param [String] api_uri
    # @param [String] api_token
    def initialize(api_uri, api_token)
      @api_uri = api_uri
      @api_token = api_token.to_s
      @subscribers = {}
      @rpc_server = Kontena::RpcServer.new
      @abort = false
      info "initialized with token #{@api_token[0..10]}..."
      @connected = false
    end

    def ensure_connect
      EM::PeriodicTimer.new(1) {
        unless connected?
          self.connect
        end
      }
    end

    # @return [Boolean]
    def connected?
      @connected
    end

    def connect
      debug 'connecting to master'
      headers = {
          'Kontena-Grid-Token' => self.api_token.to_s,
          'Kontena-Node-Id' => host_id.to_s,
          'Kontena-Version' => Kontena::Agent::VERSION
      }
      @ws = Faye::WebSocket::Client.new(self.api_uri, nil, {ping: KEEPALIVE_TIME, headers: headers})

      Pubsub.publish('websocket:connect', self)

      @ws.on :open do |event|
        self.on_open(event)
      end
      @ws.on :message do |event|
        self.on_message(@ws, event)
      end
      @ws.on :close do |event|
        self.on_close(event)
      end
      @ws.on :error do |event|
        error "connection closed with error: #{event.message}"
      end
    end

    ##
    # @param [String, Array] msg
    def send_message(msg)
      EM.next_tick {
        @ws.send(msg)
      }
    end

    # @param [Faye::WebSocket::Api::Event] event
    def on_open(event)
      info 'connection established'
      @connected = true
    end

    # @param [Faye::WebSocket::Client] ws
    # @param [Faye::WebSocket::Api::Event] event
    def on_message(ws, event)
      data = MessagePack.unpack(event.data.pack('c*'))
      if request_message?(data)
        EM.defer {
          response = @rpc_server.handle_request(data)
          self.send_message(MessagePack.dump(response).bytes)
        }
      elsif response_message?(data)
        EM.next_tick {
          Pubsub.publish("rpc_response:#{data[1]}", data)
        }
      elsif notification_message?(data)
        EM.defer {
          @rpc_server.handle_notification(data)
        }
      end
    end

    # @param [Faye::WebSocket::Api::Event] event
    def on_close(event)
      @connected = false
      if event.code == 4001
        self.handle_invalid_token(event)
      elsif event.code == 4010
        self.handle_invalid_version(event)
      end
      info "connection closed with code: #{event.code}"
    rescue => exc
      logger.error(LOG_NAME) { exc.message }
    end

    # @param [Faye::WebSocket::Api::Event] event
    def handle_invalid_token(event)
      error "master does not accept our token, shutting down ..."
      EM.next_tick{ abort("Shutting down ...") }
    end

    # @param [Faye::WebSocket::Api::Event] event
    def handle_invalid_version(event)
      agent_version = Kontena::Agent::VERSION
      error "master does not accept our version (#{agent_version}), shutting down ..."
      EM.next_tick{ abort("Shutting down ...") }
    end

    # @param [Array] msg
    # @return [Boolean]
    def request_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 0
    end

    # @param [Array] msg
    # @return [Boolean]
    def response_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 1
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
  end
end
