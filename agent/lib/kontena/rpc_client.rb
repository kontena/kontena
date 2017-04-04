require_relative 'logging'

module Kontena
  class RpcClient
    include Kontena::Logging

    class Error < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    class AsyncProxy

      def initialize(parent)
        @parent = parent
      end

      def method_missing(method, *args, &block)
        if @parent.respond_to?(method)
          EM.next_tick { @parent.send(method, *args, &block) }
        else
          raise ArgumentError.new("Method `#{method}` doesn't exist.")
        end
      end
    end

    TimeoutError = Class.new(Error)

    attr_reader :requests

    # @param [Kontena::WebsocketClient] client
    def initialize(client)
      @client = client
      @request_id = nil
      @response = nil
    end

    # @param [String] method
    # @param [Array] params
    def notification(method, params)
      EM.next_tick {
        @client.send_notification(method, params)
      }
    end

    # @return [AsyncProxy]
    def async
      AsyncProxy.new(self)
    end

    # @param [String] method
    # @param [Array] params
    # @return [Object]
    def request(method, params)
      @request_id = self.class.request_id(self)
      sleep 0.01 until @client.connected?
      @client.send_request(@request_id, method, params)
      time = Time.now.utc
      until !@response.nil?
        sleep 0.01
        raise TimeoutError.new(500, 'Request timed out') if time < (Time.now.utc - 30)
      end
      result, error = @response
      if error
        raise Error.new(error['code'], error['message'])
      end
      result
    end

    # @param [Object] result
    # @param [Object] error
    def handle_response(result, error)
      @response = [result, error]
    end

    # @return [Kontena::RpcClient]
    def self.factory
      new(self.ws_client)
    end

    # @param [Array] response
    def self.handle_response(response)
      _, msgid, error, result = response
      if client = self.requests[msgid]
        begin
          client.handle_response(result, error)
        ensure
          self.free_id(msgid)
        end
      end
    end

    # @return [Hash]
    def self.requests
      @requests ||= {}
    end

    def self.mutex
      @mutex ||= Mutex.new
    end

    # @param [RpcClient] client
    # @return [Fixnum]
    def self.request_id(client)
      id = -1
      self.mutex.synchronize {
        until id != -1 && !self.requests[id]
          id = rand(2_147_483_647)
        end
        self.requests[id] = client
      }
      id
    end

    # @param [Integer] id
    def self.free_id(id)
      self.mutex.synchronize {
        self.requests.delete(id)
      }
    end

    # @param [Kontena::WebsocketClient] client
    def self.ws_client=(client)
      @ws_client = client
    end

    # @return [Kontena::WebsocketClient, NilClass]
    def self.ws_client
      @ws_client
    end
  end
end
