module Kontena
  # An Actor that observes the value of other Obervables.
  module Observer
    include Kontena::Logging

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

    # Observer is observing some Observables, and tracking their values.
    # This object is passed to each Observable, which then sends it back via Kontena::Observable::Message for updates.
    class Observe
      include Kontena::Logging

      attr_reader :logging_prefix

      # @param cls [Class] used to identify the observer for logging
      def initialize(cls, persistent: true)
        @class = cls
        @persistent = persistent

        @observables = []
        @values = {}
        @alive = true

        @logging_prefix = "#{self}"
      end

    # Threadsafe API
      # Describe the observer for debug logging
      # Called by the Observer actor, must be threadsafe and atomic
      def to_s
        "#{self.class.name}<#{@class.name}>"
      end

      # Accepting updates from Observables?
      #
      # @return [Boolean] false => delete from Observable#observers before sending update
      def alive?
        @alive
      end

      # Accepting multiple updates from each Observable, or unregister after first one?
      #
      # @return [Boolean]
      def persistent?
        @persistent
      end

    # Observer actor API
      def inspect
        return "#{self.class.name}<#{@class.name}, #{describe_observables}>"
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

      # Receive observable update message sent to this actor, and update.
      # Suspends the calling celluloid task until updated.
      #
      # @param timeout [Float, nil] optional
      # @raise [Timeout::Error]
      def receive_and_update(timeout: nil)
        debug { "receive timeout=#{timeout}..." }

        begin
          # Celluloid.receive => Celluloid::Actor#receive => Celluloid::Internals::Receiver#receive returns nil on timeout
          message = Celluloid.receive(timeout) { |msg| Kontena::Observable::Message === msg && msg.observe == self }
        rescue Celluloid::TaskTimeout
          # Celluloid.receive => Celluloid::Mailbox.receive raises TaskTimeout insstead
          message = nil
        end

        if message
          update(message)
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

      # Wait until observable is ready, or raise on error?
      #
      # @raise if error?
      def wait(timeout: nil)
        while alive?
          if error?
            raise self.error
          elsif ready?
            return
          end

          debug { "wait: #{self.describe_observables}" }

          # XXX: timeout must be adjusted per deadline
          receive_and_update(timeout: timeout)
        end
      end

      # Yield each set of observed values while alive, or raise on error?
      #
      # The yield is exclusive, because suspending the observing task would mean that
      # any observable messages would get discarded.
      def each
        while alive?
          if error?
            raise self.error
          elsif ready?
            # prevent any intervening messages from being processed and discarded before we're back in receive()
            Celluloid.exclusive {
              yield *self.values
            }
          end

          debug { "each: #{self.describe_observables}" }

          receive_and_update
        end
      end

      # No longer expecting updates.
      #
      def kill
        @alive = false
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
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>, Observable>]
    # @param timeout [Float] optional timeout in seconds, only supported for sync mode
    # @raise [Timeout::Error] if not all observables are ready after timeout expires
    # @raise [Kontena::Observer::Error] if any observable crashes
    # @yield [*values] all Observables are ready (async mode only)
    # @return [*values] all Observables are ready (sync mode only)
    def observe(*observables, timeout: nil, &block)
      raise ArgumentError, "timeout not supported for async observe" if timeout && block

      observe = Observe.new(self.class,
        persistent: !!block || observables.length > 1,
      )
      actor = Celluloid.current_actor

      # this block should not make any suspending calls, but use exclusive mode to guarantee that regardless
      # the task must not suspend and allow any Observable messages in the mailbox to be processed before calling Celluloid.receive
      Celluloid.exclusive {
        observables.each do |observable|
          # register for observable updates, and set initial value
          if value = observable.observe(observe, actor)
            debug { "observe #{observable} => #{value}" }

            observe.add(observable, value)
          else
            debug { "observe #{observable}..." }

            observe.add(observable)
          end
        end
      }

      if block
        observe.each do |*values|
          debug { "observe async #{observe.describe_observables}: #{observe.values.join(', ')}" }

          # prevent any intervening messages from getting discarded before we re-receive
          Celluloid.exclusive {
            yield *observe.values
          }
        end
      else
        observe.wait(timeout: timeout)

        debug { "observe sync #{observe.describe_observables}: #{observe.values.join(', ')}" }

        values = observe.values

        if values.length == 1
          return values.first
        else
          return values
        end
      end
    ensure
      observe.kill
    end
  end
end
