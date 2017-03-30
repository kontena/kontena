module Kontena::Helpers::WaitHelper
  include Kontena::Logging

  WAIT_TIMEOUT = 300
  WAIT_INTERVAL = 0.5

  def _wait_now
    Time.now.to_f
  end

  # Wait until given block returns truthy value, returning nil on timeout.
  #
  # For a zero timeout, only yields exactly once.
  #
  # @param timeout [Fixnum] How long to wait
  # @param interval [Fixnum] At what interval is the block yielded
  # @param message [String] Message for debugging
  # @param block [Block] Block to yield
  # @return [Object] Return value from block, or nil
  def wait_until(message = nil, timeout: WAIT_TIMEOUT, interval: WAIT_INTERVAL, &block)
    raise ArgumentError, 'no block given' unless block_given?

    wait_start = _wait_now
    wait_until = wait_start + timeout

    value = nil

    loop do
      break if value = yield
      break if _wait_now >= wait_until

      debug "waiting %.1fs of %.1fs until: %s" % [_wait_now - wait_start + interval, timeout, message || '???']
      sleep interval
    end

    if value
      debug "waited %.1fs until: %s yielded %s" % [_wait_now - wait_start, message || '???', value]
    else
      debug "timeout after waiting %.1fs until: %s" % [_wait_now - wait_start, message || '???']
    end

    value
  end

  # Wait until given block returns truthy value, raising on timeout
  #
  # @return [Object] Last return value of the block
  # @raise [Timeout::Error] If block does not return truthy value within given timeout
  def wait_until!(message = nil, timeout: WAIT_TIMEOUT, **opts, &block)
    if value = wait_until(message, timeout: timeout, **opts, &block)
      return value
    else
      raise Timeout::Error, "Timeout after waiting %.1fs until: %s" % [timeout, message || '???']
    end
  end

  # Also allow WaitHelper.wait_until(...) to be called as a module method
  extend self
end
