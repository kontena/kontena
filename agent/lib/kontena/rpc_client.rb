require_relative 'logging'
require_relative 'helpers/wait_helper'


module Kontena
  class RpcClient
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::WaitHelper

    class Error < StandardError
      attr_accessor :code, :message, :backtrace

      def initialize(code, message, backtrace = nil)
        self.code = code
        self.message = message
        self.backtrace = backtrace
      end
    end

    class TimeoutError < Error; end

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

    # This method should not raise, or the Actor will crash, and terminate any other pending requests.
    #
    # @param [String] method
    # @param [Array] params
    # @param [Fixnum] timeout seconds
    # @return [Object, Exception]
    def request_with_error(method, params, timeout: 30)
      id = request_id
      @requests[id] = nil

      if !wait_until("websocket client is connected", timeout: timeout, interval: 0.01) { @client.connected? }
        return nil, TimeoutError.new(500, 'WebsocketClient is not connected')
      end

      @client.send_request(id, method, params)

      if !wait_until("request #{id} has response", timeout: timeout, interval: 0.01) { @requests[id] }
        return nil, TimeoutError.new(500, 'Request timed out')
      end

      result, error = @requests.delete(id)

      if error
        return result, Error.new(error['code'], error['message'])
      else
        return result, nil
      end
    end

    # Called from Kontena::WebsocketClient in the EM thread
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
