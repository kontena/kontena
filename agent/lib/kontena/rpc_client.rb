module Kontena
  class RpcClient

    class Error < StandardError
      attr_accessor :code, :message, :backtrace

      def initialize(code, message, backtrace = nil)
        self.code = code
        self.message = message
        self.backtrace = backtrace
      end
    end

    class TimeoutError < Error
    end

    attr_accessor :ws_client, :timeout

    ##
    # @param [Kontena::WebsocketClient] ws_client
    def initialize(ws_client, timeout = 10)
      @ws_client = ws_client
      @timeout = timeout
    end

    ##
    # @param [String] method
    # @return [Object]
    def request(method, *params)
      id = request_id
      ws_client.send_message(MessagePack.dump([0, id, method, params]).bytes)
      result, error = wait_for_response(id)

      if block_given?
        error = raise Error.new(error['code'], error['message'], error['backtrace']) if error
        yield(result, error)
      else
        if error
          raise Error.new(error['code'], error['message'], error['backtrace'])
        else
          result
        end
      end
    end

    ##
    # @param [String] request_id
    # @return [Array<Object>]
    def wait_for_response(request_id)
      result = nil
      error = nil
      msg_received = false
      subscription = Pubsub.subscribe("rpc_response:#{request_id}") do |msg|
        if msg && msg[0] == 1 && msg[1] == request_id
          msg_received = true
          error = msg[2]
          result = msg[3]
        end
      end
      begin
        Timeout.timeout(self.timeout) do
          sleep 0.001 until msg_received
        end
      rescue
        raise RpcClient::TimeoutError.new(503, 'Connection time out')
      ensure
        Pubsub.unsubscribe(subscription) if subscription
      end

      [result, error]
    end

    ##
    # @return [Fixnum]
    def request_id
      rand(2_147_483_647)
    end
  end
end
