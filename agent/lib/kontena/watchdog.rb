# The watchdog is intended to recover the agent from unrepairable errors by killing it, and allowing it to be restarted.
#
# The watchdog takes a block, which gets run in a separate thread every interval.
# The watchdog will abort if the block times out or fails with an exception.
#
# The watchdog abort will immediately exit! the process, without running any at_exit hooks for shutdown.
class Kontena::Watchdog
  include Celluloid
  include Kontena::Logging

  INTERVAL = 10.0
  TIMEOUT = 30.0

  def self.watch(**options, &block)
    # pass block as a proc, instead of as a celluloid block proxy
    new(block, **options)
  end

  def initialize(block, interval: INTERVAL, timeout: TIMEOUT, abort_exit: true)
    @block = block

    @interval = interval
    @timeout = timeout
    @abort_exit = abort_exit

    async.start
  end

  def start
    info "watchdog start"
    @timer = every(@interval) do
      ping
    end
  end

  # Stop the every loop from start
  def stop
    @timer.cancel
  end

  # Start new watchdog ping
  def ping
    start = Time.now

    Timeout.timeout(@timeout) do
      @block.call
    end

  rescue => exc
    error exc
    abort(exc)
  else
    delay = Time.now - start
    debug { "watchdog delay is %.3fs" % [delay] }
  end

  # kill the process
  def abort(exc)
    # only abort once
    stop

    # exit, hard, without running at_exit handlers
    exit! if @abort_exit
  end
end
