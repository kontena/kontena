# Run the given block in a separate Thread every interval, and abort if it times out or fails
class Kontena::Watchdog
  include Celluloid

  INTERVAL = 10.0
  THRESHOLD = 10.0
  TIMEOUT = 30.0

  # this is not a StandardError, it is supposed to abort the thread
  class Abort < Exception

  end

  def self.watch(**options, &block)
    new(Thread.current, block, **options)
  end

  def initialize(thread, block, interval: INTERVAL, threshold: THRESHOLD, timeout: TIMEOUT, abort: true)
    @thread = thread
    @block = block

    @interval = interval
    @threshold = threshold
    @timeout = timeout
    @abort = abort

    async.start
  end

  def logger
    Kontena::Logging.logger
  end

  def start
    logger.info "watchdog start"
    @timer = every(@interval) do
      if !@ping || @ping < @pong
        async.ping
      elsif !@pong || @pong < @ping
        check
      else

      end
    end
  end

  # Stop the every loop from start
  def stop
    @timer.cancel
  end

  def ping
    ping = @ping = Time.now

    defer {
      @block.call
    }
  rescue => exc
    logger.fatal "watchdog error: #{exc}"
    abort(exc) if @abort
  else
    @pong = Time.now if @ping == ping
  end

  def check
    delay = @pong && @pong > @ping ? @pong - @ping : Time.now - @ping

    if delay > @timeout
      bite(delay)
    elsif delay > @threshold
      bark(delay)
    else
      logger.debug { "watchdog delay is %.3fs" % [delay] }
    end
  end

  def bark(delay)
    logger.warn "watchdog delayed by %.3fs" % [delay]
  end

  def bite(delay)
    exc = Timeout::Error.new "watchdog timeout after %.3fs" % [delay]
    logger.fatal exc.message
    abort(exc) if @abort
  end

  def abort(exc)
    # only abort once
    stop

    # assume that the thread has abort_on_exception and it does not rescue non-StandardError
    @thread.raise Abort, "#{exc.class}: #{exc.message}"
  end
end
