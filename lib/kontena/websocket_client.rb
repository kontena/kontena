require 'cgi'
require 'observer'
require 'socket'
require_relative 'logging'
require_relative 'rpc_server'

module Kontena
  class WebsocketClient
    include Observable
    include Kontena::Logging

    LOG_NAME = 'WebsocketClient'
    KEEPALIVE_TIME = 30

    attr_reader :api_uri, :api_token, :ws

    ##
    # @param [String] api_uri
    # @param [String] api_token
    def initialize(api_uri, api_token)
      @api_uri = api_uri
      @api_token = api_token.to_s
      logger.info(LOG_NAME) { "initialized with token #{@api_token}" }
      @connection_retries = 0
      @subscribers = {}
    end

    def connect
      logger.debug(LOG_NAME) { 'connecting' }
      url = "#{self.api_uri}?token=#{CGI::escape(self.api_token)}&id=#{CGI::escape(host_id)}"
      @ws = Faye::WebSocket::Client.new(url, nil, {ping: KEEPALIVE_TIME})

      changed(true)
      notify_observers(self)

      @ws.on :open do |event|
        logger.info(LOG_NAME) { 'connection established' }
        @connection_retries = 0
      end
      @ws.on :message do |event|
        self.on_message(@ws, event)
      end
      @ws.on :close do |event|
        logger.info(LOG_NAME) { "connection closed with code: #{event.code}" }
        @connection_retries += 1
        sleep (2 ** @connection_retries)
        self.connect
      end
      @ws.on :error do |event|
        logger.info(LOG_NAME) { "connection closed with error: #{event.message}" }
        @connection_retries += 1
        sleep (2 ** @connection_retries)
        self.connect
      end
    end

    def send_message(msg)
      @ws.send(msg)
    end

    def on_message(ws, event)
      data = MessagePack.unpack(event.data.pack('c*'))
      if request_message?(data)
        EM.next_tick {
          response = Kontena::RpcServer.handle_request(data)
          ws.send(MessagePack.dump(response).bytes)
        }
      elsif response_message?(data)
        EM.next_tick {
          @subscribers.each{|_, value|
            value.call(data)
          }
        }
      end
    end

    def subscribe(id, &block)
      @subscribers[id] = block
    end

    def unsubscribe(id)
      @subscribers.delete(id)
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
