require_relative 'logging'
require_relative 'helpers/wait_helper'

module Kontena
  class RpcClient
    include Celluloid
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Helpers::WaitHelper

    class RequestObservable < Kontena::Observable
      def initialize(method, id)
        super("#{method}@#{id}")
      end

      def set_response(result, error)
        update([result, error])
      end
    end

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
    # @param [Float] timeout seconds
    # @raise abort
    # @return [Object]
    def request(method, params, timeout: 30)
      if !wait_until("websocket client is connected", timeout: timeout, threshold: 10.0, interval: 0.1) { connected? }
        raise TimeoutError.new(500, 'WebsocketClient is not connected')
      end

      id = request_id
      observable = @requests[id] = RequestObservable.new(method, id)

      websocket_client.send_request(id, method, params)

      begin
        result, error = observe(observable, timeout: timeout)
      rescue Timeout::Error => exc
        raise TimeoutError.new(500, exc.message)
      end

      @requests.delete(id)

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
      if observable = @requests[msgid]
        @requests[msgid].set_response(result, error)
      else
        warn "unknown response with id=#{msgid}"
      end
    end

    # @return [Integer]
    def request_id
      id = rand(REQUEST_ID_RANGE)

      while @requests.has_key?(id)
        sleep 0.01
        id = rand(REQUEST_ID_RANGE)
      end

      id
    end
  end
end
