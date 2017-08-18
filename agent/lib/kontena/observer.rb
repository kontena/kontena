module Kontena
  # An Actor that observes the value of other Obervable Actors
  module Observer
    include Kontena::Logging

    # @param observable [Celluloid::Proxy::Cell<Observable>, Observable]
    # @return [Observable]
    def self.unwrap_observable(observable)
      # #is_a? is also proxied
      Celluloid::Proxy.class_of(observable) == Celluloid::Proxy::Cell ? observable.wrapped_object : observable
    end

    def self.describe_observable(observable)
      "Observable<#{unwrap_observable(observable).class.name}>"
    end

    # Observer is observing some Observables, and tracking their values.
    # This object is passed to each Observer, which then passes it back to us for updates.
    class Observe
      # @param cls [Class] used to identify the observer for logging
      # @param observables [Array<Celluloid::Proxy::Cell<Observable>, Observable>] Observable objects, or celluloid actor proxies
      def initialize(cls, observables)
        @class = cls
        @observables = observables.map{|observable| Kontena::Observer.unwrap_observable(observable) }

        @values = Hash[@observables.map{|observable| [observable, nil]}]
      end

      def inspect
        return "#{self.class.name}<#{@class.name}, #{describe_observables}>"
      end

      # Describe the observables for debug logging
      #
      # @return [String]
      def describe_observables
        observables = @observables.map{|observable|
          "#{@values[observable] ? '' : '!'}#{observable.class.name}"
        }

        "Observable<#{observables.join(', ')}>"
      end

      # @return [String]
      def describe_values
        self.values.join(', ')
      end

      # Describe the observer for debug logging
      # Called by the Observer actor, must be threadsafe and atomic
      def to_s
        "Observer<#{@class.name}>"
      end

      # Set value for observable
      #
      # @raise [RuntimeError]
      # @return value
      def set(observable, value)
        raise "unknown observable: #{observable.inspect}" unless @values.has_key? observable
        @values[observable] = value
      end

      # Each observable has a value?
      #
      # @return [Boolean]
      def ready?
        !@values.any? { |observable, value| value.nil? }
      end

      # Map each observable to its value
      #
      # @return [Array] values or nil
      def values
        @observables.map{|observable| @values[observable] }
      end

      # Still accepting updates?
      # @return [Boolean]
      def active?
        fail NotImplementedError
      end

      # Run block or resume task
      def call
        fail NotImplementedError
      end

      class Async < Observe
        # @param actor [Celluloid::Proxy::Cell] Observing actor
        # @param block [Block] Observing block
        def initialize(cls, observables, &block)
          super(cls, observables)
          @block = block
        end

        # Persistent, expected to be updated multiple times
        # @return [Boolean]
        def active?
          true
        end

        def call
          Thread.current[:celluloid_actor].task(:observe) do
            @block.call(*values)
          end
        end
      end

      class Sync < Observe
        # @param task [Celluloid::Task] Observing task
        def initialize(cls, observables, task)
          super(cls, observables)
          @task = task
        end

        # The observe is expecting an update.
        #
        # @return [Boolean]
        def active?
          !!@task
        end

        # Cancel any further calls, the task is no longer expecting updates.
        #
        # Safe to call multiple times, prevents any further task resumes.
        def cancel
          @task = nil
        end

        # Resume waiting task
        #
        # @raise [RuntimeError] wrong state
        def call
          fail "observe task is not suspended in observe: #{@task.status}" unless @task.status == :observe

          if task = @task
            # once we've resumed the task, we can no longer re-resume it
            @task = nil
            task.resume(self)
          else
            fail "observe is not active"
          end
        end
      end
    end

    # Register celluloid actor handler for Kontena::Observable::Message.
    #
    # Updates the Observe, and calls if ready.
    def register_observer_handler
      @observer_handler ||= Thread.current[:celluloid_actor].handle(Kontena::Observable::Message) do |message|
        observe = message.observe

        if message.observable
          debug "observe update Observable<#{message.observable.class.name}> -> #{message.value}"

          observe.set(message.observable, message.value)
        end

        if !observe.active?
          debug "observe inactive: #{observe.describe_observables}"
        elsif observe.ready?
          debug "observe ready: #{observe.describe_observables}"

          observe.call
        else
          debug "observe blocked: #{observe.describe_observables}"
        end
      end
    end

    def observe(*observables, timeout: nil, &block)
      if block
        raise "timeout not supported for async observe" if timeout
        observe_async(*observables, &block)
      else
        return observe_sync(*observables, timeout: timeout)
      end
    end

    # Observe values from Observables asynchronously, yielding the observed values:
    #
    #   observe(Actors[:test_actor]) do |test|
    #     configure(foo: test.foo)
    #   end
    #
    # Yield happens once each Observable is ready, and whenever they are updated.
    # Yields to block happens from different async tasks.
    #
    # The block must be idempotent: it is not guaranteed to receive every Observable update.
    # It is only guaranteed to receive later Observable updates in the correct order,
    # and it may receive some Observable updates multiple times.
    #
    # Setup happens sync, and will raise on invalid observables.
    # Crashes this Actor if any of the observed Actors crashes.
    #
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>>]
    # @raise failed to observe observables
    # @return [Observer::Observe]
    # @yield [*values] all Observables are ready
    def observe_async(*observables, &block)
      self.register_observer_handler
      actor = Celluloid.current_actor

      # unique handle to identify this observe loop
      observe = Observe::Async.new(self.class, observables, &block)

      # sync setup of each observable
      observables.each do |observable|
        # register for async.update_observe(...)
        value = observable.add_observer(actor, observe)

        if value
          # store value for initial call, or nil to block
          observe.set(Kontena::Observer.unwrap_observable(observable), value)

          debug "observe async #{Kontena::Observer.describe_observable(observable)} => #{value}"
        else
          debug "observe async #{Kontena::Observer.describe_observable(observable)}..."
        end

        # crash if observed Actor crashes, otherwise we get stuck without updates
        # this is not a bidrectional link: our crashes do not propagate to the observable
        self.monitor observable
      end

      if observe.ready?
        debug "observe async #{observe.describe_observables}: #{observe.values.join(', ')}"

        # trigger immediate update if all observables were ready
        actor.mailbox << Kontena::Observable::Message.new(observe, nil, nil) # XXX: fake it; can't create tasks inside of tasks
      else
        debug "observe async #{observe.describe_observables}..."
      end

      observe
    end

    # Observe values from Observables synchronously, returning the observed values:
    #
    #  test = observe(Actors[:test_actor])
    #
    # This suspends the current celluloid task if any of the observables are not yet ready.
    #
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>>]
    # @param timeout [Float] optional timeout in seconds
    # @raise [Timeout::Error]
    # @return [*values]
    def observe_sync(*observables, timeout: nil)
      self.register_observer_handler

      actor = Celluloid.current_actor
      task = Celluloid::Task.current
      observe = Observe::Sync.new(self.class, observables, task)

      observables.each do |observable|
        if value = observable.add_observer(actor, observe, persistent: false)
          debug "observe sync #{Kontena::Observer.describe_observable(observable)} => #{value}"

          observe.set(Kontena::Observer.unwrap_observable(observable), value)
        else
          debug "observe sync #{Kontena::Observer.describe_observable(observable)}..."
        end
      end

      if observe.ready?
        debug "observe sync #{observe.describe_observables}: #{observe.values.join(', ')}"
      else
        debug "observe wait #{observe.describe_observables}... (timeout=#{timeout})"

        if timeout
          timer = Thread.current[:celluloid_actor].timers.after(timeout) do
            task.resume Celluloid::TaskTimeout.new
          end
        else
          timer = nil
        end

        begin
          wakeup = task.suspend(:observe)
          fail "spurious task wakeup: #{wakeup.inspect}" unless wakeup == observe
        rescue Celluloid::TaskTimeout => exc
          raise Timeout::Error, "timeout after waiting #{'%.2fs' % timeout} until: #{observe.describe_observables}"
        ensure
          timer.cancel if timer
        end

        debug "observe wait #{observe.describe_observables}: #{observe.values.join(', ')}"
      end

      if observables.length == 1
        return observe.values.first
      else
        return observe.values
      end
    ensure
      observe.cancel if observe # no longer interested in updates, the Observable can forget about us
    end
  end
end
