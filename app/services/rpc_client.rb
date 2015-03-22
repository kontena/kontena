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

  REDIS_CHANNEL = 'wharfie_rpc'

  attr_accessor :wharfie_id, :timeout

  ##
  # @param [String] wharfie_id
  def initialize(wharfie_id, timeout = 300)
    @wharfie_id = wharfie_id
    @timeout = timeout
  end

  ##
  # @param [String] method
  # @return [Object]
  def request(method, *params)
    id = request_id
    payload = {
      type: 'request',
      id: self.wharfie_id,
      message: [0, id, method, params]
    }
    $redis.with do |pub|
      pub.publish(REDIS_CHANNEL, MessagePack.dump(payload))
    end
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
    begin
      Timeout.timeout(self.timeout) do
        $redis_sub.with do |sub|
          sub.subscribe(REDIS_CHANNEL) do |on|
            on.message do |_, message|
              resp_message = MessagePack.unpack(message) rescue nil
              if resp_message && resp_message[0] == 1 && resp_message[1] == request_id
                sub.unsubscribe(REDIS_CHANNEL)
                error = resp_message[2]
                result = resp_message[3]
              end
            end
          end
        end
      end
    rescue Timeout::Error
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
