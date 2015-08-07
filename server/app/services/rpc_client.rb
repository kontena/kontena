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

  RPC_CHANNEL = 'rpc_client'

  attr_accessor :node_id, :timeout

  ##
  # @param [String] node_id
  def initialize(node_id, timeout = 300)
    @node_id = node_id
    @timeout = timeout
  end

  ##
  # @param [String] method
  # @return [Object]
  def request(method, *params)
    id = request_id
    payload = {
      type: 'request',
      id: self.node_id,
      message: [0, id, method, params]
    }
    MongoPubsub.publish_async(RPC_CHANNEL, payload)
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
    resp_message = nil
    MongoPubsub.subscribe(RPC_CHANNEL) do |subscription|
      subscription.on_message(self.timeout) do |msg|
        resp_message = msg['message']
        if resp_message && resp_message[0] == 1 && resp_message[1] == request_id
          error = resp_message[2]
          result = resp_message[3]
          subscription.terminate
        end
      end
    end
    if !resp_message && result.nil? && error.nil?
      raise RpcClient::TimeoutError.new(503, 'Connection time out')
    end

    [result, error]
  end

  ##
  # @return [Fixnum]
  def request_id
    rand(2_147_483_647)
  end
end
