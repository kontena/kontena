module WaitHelper
  include Logging

  WAIT_TIMEOUT = 300 # seconds
  WAIT_INTERVAL = 0.5 # seconds
  WAIT_THRESHOLD = 1.0 # seconds

  def _wait_now
    Time.now.to_f
  end

  # Wait until given block returns truthy value, returning nil on timeout.
  #
  # For a zero timeout, only yields exactly once.
  #
  # @param message [String] Message for debugging
  # @param timeout [Fixnum] How long to wait
  # @param interval [Fixnum] At what interval is the block yielded
  # @param threshold [Fixnum] Log slow waits after threshold
  # @param block [Block] Block to yield
  # @return [Object] Return value from block, or nil
  def wait_until(message = nil, timeout: WAIT_TIMEOUT, interval: WAIT_INTERVAL, threshold: WAIT_THRESHOLD, &block)
    raise ArgumentError, 'no block given' unless block_given?

    wait_start = _wait_now
    wait_until = wait_start + timeout
    wait_time = nil
    logging_threshold = threshold / 2

    value = nil

    loop do
      break if value = yield
      break if _wait_now >= wait_until # timeout

      if wait_time && wait_time > logging_threshold
        logging_threshold *= 2

        debug "waiting %.1fs of %.1fs until: %s" % [wait_time + interval, timeout, message || '???']
      end

      sleep interval

      wait_time = _wait_now - wait_start
    end

    if !value
      warn "timeout after waiting %.1fs of %.1fs until: %s" % [_wait_now - wait_start, timeout, message || '???']
    elsif wait_time && wait_time > threshold
      info "waited %.1fs of %.1fs until: %s yielded %s" % [_wait_now - wait_start, timeout, message || '???', value]
    elsif wait_time
      debug "waited %.1fs of %.1fs until: %s yielded %s" % [_wait_now - wait_start, timeout, message || '???', value]
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
