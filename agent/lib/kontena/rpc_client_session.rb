require_relative 'logging'

module Kontena
  class RpcClientSession
    class Error < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    TimeoutError = Class.new(Error)

    attr_reader :requests

    # @param [Kontena::WebsocketClient] client
    # @param [Kontena::RpcClient] rpc_actor
    def initialize(client, rpc_actor)
      @client = client
      @rpc_actor = rpc_actor
      @request_id = nil
      @queue = Queue.new
    end

    # @param [String] method
    # @param [Array] params
    def notification(method, params)
      @client.send_notification(method, params)
    end

    # @param [String] method
    # @param [Array] params
    # @return [Object]
    def request(method, params)
      request_id = self.request_id
      sleep 0.01 until @client.connected?

      @client.send_request(request_id, method, params)
      response = nil
      Timeout::timeout(30) {
        response = @queue.pop
      }
      result, error = response
      if error
        raise Error.new(error['code'], error['message'])
      end
      result
    rescue Timeout::Error
      raise TimeoutError.new(500, 'Request timed out')
    end

    # @param [Object] result
    # @param [Object] error
    def handle_response(result, error)
      @queue << [result, error]
    end

    # @return [Integer]
    def request_id
      @rpc_actor.request_id(self)
    end
  end
end
