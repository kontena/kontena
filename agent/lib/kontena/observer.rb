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
      # @param cls [Class] used to identify the observer for logging
      def initialize(cls, persistent: true)
        @class = cls
        @persistent = persistent

        @observables = []
        @values = {}
        @alive = true
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
      # @raise [RuntimeError]
      # @return value
      def set(observable, value)
        raise "unknown observable: #{observable.class.name}" unless @values.has_key? observable
        @values[observable] = value
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

      # No longer expecting updates.
      #
      def kill
        @alive = false
      end
    end

    # Update the Observe, and call it if ready, which will active the observe task.
    # Must be called from Celluloid::Actor#handle directly in the Actor thread.
    # Do not call this from any task context.
    #
    # @param message [Kontena::Observable::Message]
    def update_observe(message)
      observe = message.observe

      if message.observable
        debug { "observe update #{message.observable} -> #{message.value}" }

        observe.set(message.observable, message.value)
      end

      if !observe.alive?
        debug { "observe dead: #{observe.describe_observables}" }
      elsif observe.error?
        debug { "observe crashed: #{observe.describe_observables}" }
        observe.crash
      elsif observe.ready?
        debug { "observe ready: #{observe.describe_observables}" }
        observe.call
      else
        debug { "observe blocked: #{observe.describe_observables}" }
      end
    end

    # Observe values from Observables, either synchronously or asynchronously.
    #
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>, Observable>]
    # @param timeout [Float] optional timeout in seconds, only supported for sync mode
    # @see [#observe_async] yields if block is given
    # @see [#observe_sync] returns unless block is given
    def observe(*observables, timeout: nil, &block)
      observe = Observe.new(self.class,
        persistent: !!block || observables.length > 1,
      )
      actor = Celluloid.current_actor

      # atomic setup of observes, task must not suspend and allow mailbox to be processed before calling Celluloid.receive
      observables.each do |observable|
        # register for observable updates, and set initial value
        if value = observable.observe(observe, actor)
          debug { "observe async #{observable} => #{value}" }

          observe.add(observable, value)
        else
          debug { "observe async #{observable}..." }

          observe.add(observable)
        end
      end

      if block
        raise "timeout not supported for async observe" if timeout
        observe_async(observe, &block)
      else
        return observe_sync(observe, timeout: timeout)
      end
    ensure
      observe.kill
    end

    # Observe values from Observables asynchronously, yielding the observed values:
    #
    #   observe(Actors[:test_actor]) do |test|
    #     configure(foo: test.foo)
    #   end
    #
    # Yields from an async task once each Observable is ready, and again whenever any observable updates.
    # Raises if any of the observed Actors crashes.
    # Does not return.
    #
    # Does not yield if any Observable resets, until all Observables are ready again.
    # Does not yield if the previous async block task is still running.
    # Yields again after the block returns, if any observables have updated during the execution of the block.
    #
    # The block must be idempotent: it is not guaranteed to receive every Observable update,
    # and it may receive some Observable updates multiple times.
    # It is guaranteed to receive Observable updates in the correct order.
    #
    # @raise [Celluloid::DeadActorError]
    # @return never
    # @yield [*values] all Observables are ready
    def observe_async(observe, &block)
      while true
        if observe.ready?
          debug { "observe async #{observe.describe_observables}: #{observe.values.join(', ')}" }

          # execute block and prevent any intervening messages from getting discarded before we re-receive
          Celluloid.exclusive {
            yield *observe.values
          }
        end

        debug { "observe async #{observe.describe_observables}..." }

        message = Celluloid.receive { |msg| Kontena::Observable::Message === msg && msg.observe == observe }

        debug { "observe async #{message.observable} -> #{message.value}" }

        observe.set(message.observable, message.value)

        debug { "observe async #{observe.describe_observables}: #{observe.values.join(', ')}" }

        raise observe.error if observe.error?
      end
    end

    # Observe values from Observables synchronously, returning the observed values:
    #
    #  test = observe(Actors[:test_actor])
    #
    # Returns once all of the observables are ready, blocking the current thread or celluloid task.
    # Returns the most recent value of each Observable.
    # Raises with Timeout::Error if a timeout is given, and any observable is not yet ready.
    # Crashes the actor if any observed actor crashes during the wait.
    #
    # @param timeout [Float] optional timeout in seconds
    # @raise [Timeout::Error]
    # @raise [Celluloid::DeadActorError]
    # @return [*values]
    def observe_sync(observe, timeout: nil)
      while !observe.ready?
        debug { "observe wait #{observe.describe_observables}... (wait timeout=#{timeout})" }

        # XXX: timeout must be adjusted from deadline
        begin
          # XXX: Celluloid.receive => Celluloid::Actor#receive => Celluloid::Internals::Receiver#receive returns nil on timeout
          message = Celluloid.receive(timeout) { |msg| Kontena::Observable::Message === msg && msg.observe == observe }
        rescue Celluloid::TaskTimeout
          # XXX: Celluloid.receive => Celluloid::Mailbox.receive raises TaskTimeout insstead
          message = nil
        end

        if message
          debug { "observe update #{message.observable} -> #{message.value}" }

          observe.set(message.observable, message.value)

          debug { "observe wait #{observe.describe_observables}: #{observe.values.join(', ')}" }

          raise observe.error if observe.error?
        else
          raise Timeout::Error, "observe timeout #{'%.2fs' % timeout}: #{observe.describe_observables}"
        end
      end

      values = observe.values

      if values.length == 1
        return values.first
      else
        return values
      end
    end
  end
end
