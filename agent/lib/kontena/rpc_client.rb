require_relative 'logging'

module Kontena
  class RpcClient
    include Celluloid
    include Kontena::Logging

    class Error < StandardError
      attr_reader :code, :remote_backtrace

      def initialize(code, message, remote_backtrace = nil)
        @code = code
        @remote_backtrace = (['<Remote>:'] + remote_backtrace) if remote_backtrace
        super(message)
      end

      def backtrace
        super + Array(remote_backtrace)
      end
    end

    TimeoutError = Class.new(Error)

    attr_reader :requests

    # @param [Kontena::WebsocketClient] client
    def initialize(client)
      @requests = {}
      @client = client
      info 'initialized'
    end

    # @param [String] method
    # @param [Array] params
    def notification(method, params)
      @client.send_notification(method, params)
    rescue => exc
      logger.error exc.message
    end

    # @param [String] method
    # @param [Array] params
    # @return [Celluloid::Future]
    def request(method, params)
      id = request_id
      @requests[id] = nil
      future = Celluloid::Future.new {
        sleep 0.01 until @client.connected?
        @client.send_request(id, method, params)
        time = Time.now.utc
        until !@requests[id].nil?
          sleep 0.01
          raise TimeoutError.new(500, 'Request timed out') if time < (Time.now.utc - 30)
        end
        result, error = @requests.delete(id)
        if error
          raise Error.new(error['code'], error['message'], error['backtrace'])
        end
        result
      }

      future
    end

    def handle_response(response)
      type, msgid, error, result = response
      @requests[msgid] = [result, error]
    end

    # @return [Fixnum]
    def request_id
      id = -1
      until id != -1 && !@requests[id]
        id = rand(2_147_483_647)
      end
      id
    end
  end
end
