module Kontena
  # Observer is observing some Observables, and tracking their values.
  # This object is passed to each Observable, which then sends it back via Kontena::Observable::Message for updates.
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

    # Mixin module providing the observe method
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
    #   Returns once all of the observables are ready, blocking the current thread or celluloid task.
    #   Returns the most recent value of each Observable.
    #   Raises with Timeout::Error if a timeout is given, and any observable is not yet ready.
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
    #   Does not return.
    #
    #   Yields in exclusive mode.
    #   Preserves Observable update ordering: each Observable update will be seen in order.
    #
    # @param observables [Array<Observable>]
    # @param subject [String] identify the Observer for logging purposes
    # @param timeout [Float] optional timeout in seconds, only supported for sync mode
    # @raise [Timeout::Error] if not all observables are ready after timeout expires
    # @raise [Kontena::Observer::Error] if any observable crashes
    # @yield [*values] all Observables are ready (async mode only)
    # @return [*values] all Observables are ready (sync mode only)
    def self.observe(*observables, subject: nil, timeout: nil, &block)
      observer = self.new(subject, Celluloid.current_actor.mailbox)

      persistent = true
      persistent = false if !block && observables.length == 1 # special case: sync observe of a single observable does not need updates

      # this block should not make any suspending calls, but use exclusive mode to guarantee that regardless
      # the task must not suspend and allow any Observable messages in the mailbox to be processed before calling Celluloid.receive
      Celluloid.exclusive {
        observables.each do |observable|
          # register for observable updates, and set initial value
          if value = observable.add_observer(observer, persistent: persistent)
            observer.add(observable, value)
          else
            observer.add(observable)
          end
        end
      }

      if block
        observer.each(timeout: timeout, &block)
      else
        observer.each(timeout: timeout) do |*values|
          # workaround `return *observe.values` not working as expected
          if observables.length > 1
            return observer.values
          else
            return observer.values.first
          end
        end
      end
    ensure
      observer.kill
    end

    # @param subject [Object] used to identify the Observer for logging purposes
    # @param mailbox [Celluloid::Mailbox] send/receive messages
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
    # Called by the Observer actor, must be threadsafe and atomic
    def to_s
      "#{self.class.name}<#{@subject}>"
    end

    # Accepting updates from Observables?
    #
    # @return [Boolean] false => delete from Observable#observers before sending update
    def alive?
      @alive && @mailbox.alive?
    end

    # Update Observer
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

    # Add Observable with initial value
    #
    # @param observable [Observable]
    # @param value [Object] nil if not yet ready
    def add(observable, value = nil)
      if value
        debug { "add #{observable} => #{value}" }
      else
        debug { "add #{observable}..." }
      end

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

    # Update observable value from message
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
        message = Celluloid.receive(timeout) { |msg| Kontena::Observable::Message === msg && msg.observe == self }
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
    # @return [Boolean] true => call to crash
    def error?
      @values.any? { |observable, value| Exception === value }
    end

    # Each observable has a value?
    #
    # @return [Boolean] false => block calls on updates
    def ready?
      !@values.any? { |observable, value| value.nil? }
    end

    # Map each observable to its value
    #
    # @return [Array] values or nil
    def values
      @observables.map{|observable| @values[observable] }
    end

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

      while alive?
        # prevent any intervening messages from being processed and discarded before we're back in Celluloid.receive()
        Celluloid.exclusive {
          if error?
            debug { "raise: #{self.describe_observables}" }

            raise self.error
          elsif ready?
            debug { "yield: #{self.describe_observables}" }

            yield *self.values

            @deadline = Time.now + timeout if timeout
          else
            debug { "wait: #{self.describe_observables}" }
          end
        }

        # must be atomic!
        update(receive())
      end
    end

    # No longer expecting updates.
    #
    def kill
      @alive = false
    end
  end
end
