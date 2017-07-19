require_relative 'logging'
require_relative 'helpers/wait_helper'


module Kontena
  class RpcClient
    include Celluloid
    include Kontena::Logging
    include Kontena::Helpers::WaitHelper

    REQUEST_ID_RANGE = 1..2**31

    class Error < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    TimeoutError = Class.new(Error)

    attr_reader :requests

    def initialize
      @requests = {}
      info 'initialized'
    end

    def websocket_client
      Celluloid::Actor[:websocket_client]
    end

    def connected?
      websocket_client && websocket_client.connected?
    end

    # @param [String] method
    # @param [Array] params
    def notification(method, params)
      websocket_client.async.send_notification(method, params)
    rescue => exc
      logger.error exc.message
    end

    # Aborts caller on errors.
    #
    # @param [String] method
    # @param [Array] params
    # @param [Fixnum] timeout seconds
    # @raise abort
    # @return [Object]
    def request(method, params, timeout: 30)
      id = request_id
      @requests[id] = nil

      if !wait_until("websocket client is connected", timeout: timeout, threshold: 10.0, interval: 0.1) { connected? }
        raise TimeoutError.new(500, 'WebsocketClient is not connected')
      end

      websocket_client.send_request(id, method, params)

      if !wait_until("request #{method} has response wth id=#{id}", timeout: timeout, interval: 0.01) { @requests[id] }
        raise TimeoutError.new(500, 'Request timed out')
      end

      result, error = @requests.delete(id)

      if error
        raise Error.new(error['code'], error['message'])
      else
        return result
      end
    rescue => exc
      warn exc
      abort exc
    end

    # Sent by the Kontena::WebsocketClient actor
    def handle_response(response)
      type, msgid, error, result = response
      @requests[msgid] = [result, error]
    end

    # @return [Fixnum]
    def request_id
      id = rand(REQUEST_ID_RANGE)

      while @requests.has_key?(id)
        sleep 0.001
        id = rand(REQUEST_ID_RANGE)
      end

      id
    end
  end
end
