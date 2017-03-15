module WaitHelper
  include Logging

  WAIT_TIMEOUT = 300
  WAIT_INTERVAL = 0.5

  # Wait until given block returns truthy value, returning nil on timeout
  #
  # @param timeout [Fixnum] How long to wait
  # @param interval [Fixnum] At what interval is the block yielded
  # @param message [String] Message for debugging
  # @param block [Block] Block to yield
  # @return [Object] Return value from block, or nil
  def wait(timeout: WAIT_TIMEOUT, interval: WAIT_INTERVAL, message: nil, &block)
    raise ArgumentError, 'no block given' unless block_given?

    wait_until = Time.now.to_f + timeout

    loop do
      return nil if Time.now.to_f > wait_until

      value = yield

      if value
        return value
      else
        debug "wait... #{message}"
        sleep interval
      end
    end
  end

  # Wait until given block returns truthy value, raising on timeout
  #
  # @return [Object] Last return value of the block
  # @raise [Timeout::Error] If block does not return truthy value within given timeout
  def wait!(**opts, &block)
    if value = wait(**opts, &block)
      return value
    else
      raise Timeout::Error
    end
  end

  # XXX: also used in class methods
  extend self
end
