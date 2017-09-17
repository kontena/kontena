require_relative 'mongo_pubsub'

class RpcClient

  class Error < StandardError
    attr_reader :code, :remote_backtrace

    def initialize(code, message, remote_backtrace = nil)
      @code = code
      @remote_backtrace = remote_backtrace
      super(message)
    end

    def backtrace
      # this must return nil if no local backtrace is set yet, or ruby will not set any backtrace on raise
      local_backtrace = super

      if local_backtrace && @remote_backtrace
        remote_backtrace.map{|line| 'agent:' + line} + ["<RPC>"] + local_backtrace
      else
        local_backtrace
      end
    end
  end

  TimeoutError = Class.new(Error)

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
  # @param [Array<Object>] params
  # @return [Object]
  def request(method, *params)
    id = request_id
    payload = {
      type: 'request',
      id: self.node_id,
      message: [0, id, method, params]
    }
    response = []
    subscription = subscribe_to_response(id, response)
    MasterPubsub.publish_async(RPC_CHANNEL, payload)
    result, error = wait_for_response(subscription, response)

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
  # @param [Integer] request_id
  # @param [Array] resp
  # @return [MongoPubsub::Subscription]
  def subscribe_to_response(request_id, resp)
    MasterPubsub.subscribe("#{RPC_CHANNEL}:#{request_id}") do |msg|
      resp_message = msg['message']
      if resp_message && resp_message[0] == 1 && resp_message[1] == request_id
        error = resp_message[2]
        result = resp_message[3]
        resp << result
        resp << error
      end
    end
  end

  # @param [MongoPubsub::Subscription] subscription
  # @param [Array] resp
  # @return [Array]
  def wait_for_response(subscription, resp)
    wait = self.timeout.to_i.seconds.from_now.to_f
    sleep 0.01 until (resp.size == 2 || wait < Time.now.to_f)
    unless resp.size == 2
      raise RpcClient::TimeoutError.new(503, "Connection timeout (#{self.timeout}s)")
    end
    resp
  ensure
    subscription.terminate
  end

  # @param [String] method
  # @param [Array<Object>] params
  def notify(method, *params)
    payload = {
        type: 'notify',
        id: self.node_id,
        message: [2, method, params]
    }
    MasterPubsub.publish_async(RPC_CHANNEL, payload)
  end

  ##
  # @return [Integer]
  def request_id
    rand(2_147_483_647)
  end
end
