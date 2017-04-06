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

      if !wait_until("websocket client is connected", timeout: timeout, interval: 0.1) { @client.connected? }
        return nil, TimeoutError.new(500, 'WebsocketClient is not connected')
      end

      @client.send_request(id, method, params)

      if !wait_until("request #{method} has response wth id=#{id}", timeout: timeout, interval: 0.01) { @requests[id] }
        return nil, TimeoutError.new(500, 'Request timed out')
      end

      result, error = @requests.delete(id)

      if error
        return result, Error.new(error['code'], error['message'])
      else
        return result, nil
      end
    end

    # Async request wrapper.
    #
    # Logs a warning and returns nil on errors.
    # Use Kontena::Helpers::RpcError.rpc_request to get a raised error instead.
    #
    # @return [Object, nil]
    def request(method, params, **opts)
      result, error = request_with_error(method, params, **opts)

      if error
        warn "RPC request #{method} failed: #{error}"
        return nil
      else
        return result
      end
    end

    # Called from Kontena::WebsocketClient in the EM thread
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
