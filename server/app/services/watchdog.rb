class Watchdog
  include Celluloid

  # this is not a StandardError, it is supposed to abort the thread
  class Abort < Exception

  end

  INTERVAL = 0.5
  THRESHOLD = 1.0
  TIMEOUT = 60.0
  ABORT = true

  LOG_LEVEL = Logger::INFO

  def self.logger(subject, target: STDOUT, level: ENV["WATCHDOG_DEBUG"] ? Logger::DEBUG : LOG_LEVEL)
    logger = Logger.new(target)
    logger.progname = "#{self.name}<#{subject}>"
    logger.level = level
    logger
  end

  attr_reader :logger

  # @param subject [String] used for logging, describe what is pinging this watchdog
  # @param thread [Thread] thread to trace and abort on watchdog timeouts
  # @param interval [Integer] expect to get a ping every interval seconds
  # @param threshold [Integer] log warnings if pings interval goes above threshold seconds
  # @param timeout [Integer] log fatal if ping interval goes above timeout seconds
  # @param abort [Boolean] abort thread on timeout by raising Watchdog::Abort
  def initialize(subject, thread, interval: INTERVAL, threshold: THRESHOLD, timeout: TIMEOUT, abort: ABORT, start: true)
    @logger = self.class.logger(subject)

    @subject = subject
    @thread = thread
    @interval = interval
    @threshold = threshold
    @timeout = timeout
    @abort = abort

    @ping = Time.now

    async.start if start
  end

  # Keep the watchdog happy by pinging it every interval
  def ping
    @ping = Time.now
  end

  # Start checking for pings
  def start
    logger.info "watchdog start"
    @timer = every(@interval) do
      check
    end
  end

  # Stop the every loop from start
  def stop
    @timer.cancel
  end

  def check
    delay = Time.now - @ping

    if delay > @timeout
      logger.fatal "watchdog timeout after %.3fs @\n\t%s" % [delay, trace.join("\n\t")]
      abort if @abort

    elsif delay > @threshold
      logger.warn "watchdog delayed by %.3fs @\n\t%s" % [delay, trace.join("\n\t")]

    else
      logger.debug { "watchdog delay is %.3fs" % [delay] }
    end
  end

  # @return [Array<String>] current target thread stack
  def trace
    @thread.backtrace
  end

  # Abort the target thread by raising Watchdog::Abort.
  # Stops the watchdog, we don't expect to receive any more pings.
  def abort
    # only abort once
    self.stop

    # assume that the thread has abort_on_exception and it does not rescue non-StandardError
    @thread.raise Abort, "ABORT #{@subject} watchdog timeout"
  end
end
