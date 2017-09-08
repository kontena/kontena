module Kontena
  # Observer is observing some Observables, and tracking their observed values.
  #
  # The initial observe => Observable.add_observer happens synchronously, protected by the Observable mutex.
  # The future observable updates are sent as messages to the Observer mailbox.
  # The observing task is responsible for reciving each observable update message.
  #
  # The Observable gets a reference to the Observer, which is used to receive the message from the correct observing task.
  class Observer
    include Kontena::Logging

    attr_reader :logging_prefix # customize Kontena::Logging#logging_prefix by instance

    class Error < StandardError
      attr_reader :observable, :cause

      def initialize(observable, cause)
        super(cause.message)
        @observable = observable
        @cause = cause
      end

      def to_s
        "#{@cause.class}@#{@observable}: #{super}"
      end
    end

    # Mixin module providing the #observe method
    module Helper

      # @see Kontena::Observe#observe
      #
      # Wrapper that defaults subject to the name of the including class.
      def observe(*observables, **options, &block)
        Kontena::Observer.observe(*observables, subject: self.class.name, **options, &block)
      end
    end

    # Observe values from Observables, either synchronously or asynchronously:
    #
    # Synchronous mode, without a block:
    #
    #     value = observe(observable)
    #
    #     value1, value2 = observe(observable1, observable2)
    #
    #   Returns once all of the observables are ready, suspending the current thread or celluloid task.
    #   Returns the most recent value of each Observable.
    #   Raises with Timeout::Error if a timeout is given, and not all observables are ready.
    #   Raises with Kontena::Observer::Error if any observable crashes during the wait.
    #
    # Asynchronous mode, with a block:
    #
    #    observe(observable) do |value|
    #      handle(value)
    #    end
    #
    #    observe(observable1, observable2) do |value1, value2|
    #      handle(value1, value2)
    #    end
    #
    #   Yields once all Observables are ready.
    #   Yields again whenever any Observable updates.
    #   Does not yield if any Observable resets, until ready again.
    #   Raises if any of the observed Actors crashes.
    #   Does not return, unless the block itself breaks/returns.
    #
    #   Suspends the task in between yields.
    #   Yields in exclusive mode.
    #   Preserves Observable update ordering: each Observable update will be seen in order.
    #   Raises with Timeout::Error if a timeout is given, and any observable is not yet ready or stops updating.
    #   Raises with Kontena::Observer::Error if any observable crashes during the observe.
    #
    # @param observables [Array<Observable>]
    # @param subject [String] identify the Observer for logging purposes
    # @param timeout [Float] (seconds) optional timeout for sync return or async yield
    # @raise [Timeout::Error] if not all observables are ready after timeout expires
    # @raise [Kontena::Observer::Error] if any observable crashes
    # @yield [*values] all Observables are ready (async mode only)
    # @return [*values] all Observables are ready (sync mode only)
    def self.observe(*observables, subject: nil, timeout: nil)
      observer = self.new(subject, Celluloid.mailbox)

      persistent = true
      persistent = false if !block_given? && observables.length == 1 # special case: sync observe of a single observable does not need updates

      # must not suspend and risk discarding any messages in between observing and receiving from each()!
      Celluloid.exclusive {
        # this block should not make any suspending calls, but use exclusive mode to guarantee that regardless
        observables.each do |observable|
          observer.observe(observable, persistent: persistent)
        end
      }

      # NOTE: yields in exclusive mode!
      observer.each(timeout: timeout) do |*values|
        # return or yield observed value
        if block_given?
          observer.debug { "yield #{observer.describe_observables} => #{observer.describe_values}" }

          yield *values
        else
          observer.debug { "return #{observer.describe_observables} => #{observer.describe_values}" }

          # workaround `return *values` not working as expected
          if values.length > 1
            return values
          else
            return values.first
          end
        end
      end
    ensure
      observer.kill if observer
    end

    # @param subject [Object] used to identify the Observer for logging purposes
    # @param mailbox [Celluloid::Mailbox] Observable sends messages to mailbox, Observer receives messages from mailbox
    def initialize(subject, mailbox)
      @subject = subject
      @mailbox = mailbox

      @observables = []
      @values = {}
      @alive = true
      @deadline = nil

      @logging_prefix = "#{self}"
    end

  # threadsafe API
    # Describe the observer for debug logging
    # Called by the Observer from other actors, must be threadsafe and atomic
    def to_s
      "#{self.class.name}<#{@subject}>"
    end

    # Still interested in updates from Observables?
    # Any messages sent after no longer alive are harmless and will just be discarded.
    #
    # @return [Boolean] false => observed observables will drop this observer
    def alive?
      @alive && @mailbox.alive?
    end

    # Update Observer.
    #
    # If the Observer is dead by the time the message is sent to the mailbox, or
    # before it gets processed, the message will be safely discarded.
    #
    # @param message [Kontena::Observable::Message]
    def <<(message)
      @mailbox << message
    end

  # non-threadsafe API
    def inspect
      return "#{self.class.name}<#{@subject}, #{describe_observables}>"
    end

    # Describe the observables for debug logging
    #
    # Each Observable will include a symbol showing its current state:
    #
    # * Kontena::Observable<TestActor>   => ready
    # * Kontena::Observable<TestActor>!  => crashed
    # * Kontena::Observable<TestActor>?  => not ready
    #
    # @return [String]
    def describe_observables
      @observables.map{|observable|
        sym = (case value = @values[observable]
        when nil
          '?'
        when Exception
          '!'
        else
          ''
        end)

        "#{observable}#{sym}"
      }.join(', ')
    end

    # @return [String]
    def describe_values
      self.values.join(', ')
    end

    # Observe observable: add Observer to Observable, and add Observable to Observer.
    #
    # NOTE: Must be called from exclusive mode, to ensure that any resulting Observable messages are nost lost before calling receive!
    #
    # @param observable [Kontena::Observable]
    # @param persistent [Boolean] false => only interested in current or initial value
    def observe(observable, persistent: true)
      # register for observable updates, and set initial value
      if value = observable.add_observer(self, persistent: persistent)
        debug { "observe #{observable} => #{value}" }

        add(observable, value)
      else
        debug { "observe #{observable}..." }

        add(observable)
      end
    end

    # Add Observable with initial value
    #
    # @param observable [Kontena::Observable]
    # @param value [Object] nil if not yet ready
    def add(observable, value = nil)
      @observables << observable
      @values[observable] = value
    end

    # Set value for observable
    #
    # @raise [RuntimeError] unknown observable
    # @return value
    def set(observable, value)
      raise "unknown observable: #{observable.class.name}" unless @values.has_key? observable

      @values[observable] = value
    end

    # Update observed value from message
    #
    # @param message [Kontena::Observable::Message]
    def update(message)
      debug { "update #{message.observable} -> #{message.value}" }

      set(message.observable, message.value)
    end

    # Return next observable messages sent to this actor from Observables using #<<
    # Suspends the calling celluloid task in between message yields.
    # Must be called atomically, suspending in between calls to receive() risks missing intervening messages!
    #
    # @raise [Timeout::Error]
    def receive
      timeout = @deadline ? @deadline - Time.now : nil

      debug { "receive timeout=#{timeout}..." }

      begin
        # Celluloid.receive => Celluloid::Actor#receive => Celluloid::Internals::Receiver#receive returns nil on timeout
        message = Celluloid.receive(timeout) { |msg| Kontena::Observable::Message === msg && msg.observer == self }
      rescue Celluloid::TaskTimeout
        # Celluloid.receive => Celluloid::Mailbox.receive raises TaskTimeout insstead
        message = nil
      end

      if message
        return message
      else
        raise Timeout::Error, "observe timeout #{'%.2fs' % timeout}: #{self.describe_observables}"
      end
    end

    # Any observable has an error?
    #
    # @return [Boolean] true => some observed value is an Exception
    def error?
      @values.any? { |observable, value| Exception === value }
    end

    # Every observable has a value?
    #
    # @return [Boolean] false => some observed values are still nil
    def ready?
      !@values.any? { |observable, value| value.nil? }
    end

    # Map each observed observable to its value.
    #
    # Should only be used once ready?
    #
    # @return [Array] observed values
    def values
      @observables.map{|observable| @values[observable] }
    end

    # Return Error for first crashed observable.
    #
    # Should only be used if error?
    #
    # @return [Exception, nil]
    def error
      @values.each_pair{|observable, value|
        return Error.new(observable, value) if Exception === value
      }
      return nil
    end

    # Yield each set of ready? observed values while alive, or raise on error?
    #
    # The yield is exclusive, because suspending the observing task would mean that
    # any observable messages would get discarded.
    #
    # @param timeout [Float] timeout between each yield
    def each(timeout: nil)
      @deadline = Time.now + timeout if timeout

      while true
        # prevent any intervening messages from being processed and discarded before we're back in Celluloid.receive()
        Celluloid.exclusive {
          if error?
            debug { "raise: #{self.describe_observables}" }

            raise self.error
          elsif ready?
            yield *self.values

            @deadline = Time.now + timeout if timeout
          end
        }

        # must be atomic!
        debug { "wait: #{self.describe_observables}" }

        update(receive())
      end
    end

    # No longer expecting updates from any Observables.
    # Any messages sent to our mailbox will just be discarded.
    # All observed Observables will eventually notice we are dead, and drop us from their observers.
    #
    def kill
      @alive = false
    end
  end
end
