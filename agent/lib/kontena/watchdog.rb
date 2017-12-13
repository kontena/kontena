# Run the given block in a separate Thread every interval, and abort if it times out or fails
class Kontena::Watchdog
  include Celluloid
  include Kontena::Logging

  INTERVAL = 10.0
  THRESHOLD = 10.0
  TIMEOUT = 30.0

  def self.watch(**options, &block)
    # pass block as a proc, instead of as a celluloid block proxy
    new(block, **options)
  end

  def initialize(block, interval: INTERVAL, threshold: THRESHOLD, timeout: TIMEOUT, abort_exit: true)
    @block = block

    @interval = interval
    @threshold = threshold
    @timeout = timeout
    @abort_exit = abort_exit

    async.start
  end

  def start
    info "watchdog start"
    @timer = every(@interval) do
      if !@ping || (@pong && @ping < @pong)
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

  # Start new watchdog ping
  def ping
    ping = @ping = Time.now

    defer {
      @ping_thread = Thread.current

      @block.call

      @ping_thread = nil
    }

  rescue => exc
    abort(exc)
  else
    pong(ping, Time.now)
  end

  def pong(ping, pong)
    @pong = pong if @ping == ping
  end

  # Watchdog has not yet seen any @pong for the latest @ping, warn on threshold and abort on timeout
  def check
    delay = Time.now - @ping

    if delay > @timeout
      bite(delay)
    elsif delay > @threshold
      bark(delay)
    else
      debug { "watchdog delay is %.3fs" % [delay] }
    end
  end

  # @return [Array<String>] current target thread stack
  def trace
    (@ping_thread && @ping_thread.backtrace) || []
  end

  # warn when @ping delay exceeds @threshold
  # @param delay [Float] > @threshold
  def bark(delay)
    warn "watchdog delayed by %.3fs @ %s" % [delay, trace.join("\n\t")]
  end

  # abort when @ping delay exceeds @timeout
  # @param delay [Float] > @timeout
  def bite(delay)
    exc = Timeout::Error.new "watchdog timeout after %.3fs @ %s" % [delay, trace.join("\n\t")]
    abort(exc)
  end

  # kill the watched Thread
  def abort(exc)
    error exc

    # only abort once
    stop

    # exit, hard, without running at_exit handlers
    exit! if @abort_exit
  end
end
