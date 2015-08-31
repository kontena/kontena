require 'cgi'
require 'socket'
require_relative 'logging'
require_relative 'rpc_server'

module Kontena
  class WebsocketClient
    include Kontena::Logging

    LOG_NAME = 'WebsocketClient'
    KEEPALIVE_TIME = 30

    attr_reader :api_uri, :api_token, :ws
    delegate :on, to: :ws

    ##
    # @param [String] api_uri
    # @param [String] api_token
    def initialize(api_uri, api_token)
      @api_uri = api_uri
      @api_token = api_token.to_s
      logger.info(LOG_NAME) { "initialized with token #{@api_token}" }
      @subscribers = {}
      @rpc_server = Kontena::RpcServer.new
    end

    def connect
      logger.debug(LOG_NAME) { 'connecting' }
      headers = {
          'Kontena-Grid-Token' => self.api_token.to_s,
          'Kontena-Node-Id' => host_id.to_s
      }
      @ws = Faye::WebSocket::Client.new(self.api_uri, nil, {ping: KEEPALIVE_TIME, headers: headers})

      Pubsub.publish('websocket:connect', self)

      @ws.on :open do |event|
        logger.info(LOG_NAME) { 'connection established' }
      end
      @ws.on :message do |event|
        self.on_message(@ws, event)
      end
      @ws.on :close do |event|
        logger.info(LOG_NAME) { "connection closed with code: #{event.code}" }
        sleep 1
        self.connect
      end
      @ws.on :error do |event|
        logger.info(LOG_NAME) { "connection closed with error: #{event.message}" }
      end
    end

    ##
    # @param [String, Array] msg
    def send_message(msg)
      EM.next_tick {
        @ws.send(msg)
      }
    end

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
      end
    end

    def request_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 0
    end

    def response_message?(msg)
      msg.is_a?(Array) && msg.size == 4 && msg[0] == 1
    end

    def host_id
      Docker.info['ID']
    end
  end
end
