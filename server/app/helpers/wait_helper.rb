module WaitHelper
  include Logging

  WAIT_TIMEOUT = 300
  WAIT_INTERVAL = 0.5

  def _wait_now
    Time.now.to_f
  end

  # Wait until given block returns truthy value, returning nil on timeout
  #
  # @param timeout [Fixnum] How long to wait
  # @param interval [Fixnum] At what interval is the block yielded
  # @param message [String] Message for debugging
  # @param block [Block] Block to yield
  # @return [Object] Return value from block, or nil
  def wait_until(timeout: WAIT_TIMEOUT, interval: WAIT_INTERVAL, message: nil, &block)
    raise ArgumentError, 'no block given' unless block_given?

    wait_until = _wait_now + timeout

    loop do
      return nil if _wait_now > wait_until

      value = yield

      if value
        return value
      else
        debug "wait... #{message}" if message
        sleep interval
      end
    end
  end

  # Wait until given block returns truthy value, raising on timeout
  #
  # @return [Object] Last return value of the block
  # @raise [Timeout::Error] If block does not return truthy value within given timeout
  def wait_until!(**opts, &block)
    if value = wait_until(**opts, &block)
      return value
    else
      raise Timeout::Error
    end
  end

  # Also allow WaitHelper.wait_until(...) to be called as a module method
  extend self
end
