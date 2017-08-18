class Celluloid::Actor
  attr_accessor :observe_handler
end

module Kontena
  # An Actor that observes the value of other Obervable Actors
  module Observer
    include Kontena::Logging

    # Observer is observing some Observables, and tracking their values.
    # This object is passed to each Observer, which then passes it back to us for updates.
    class Observe
      # @param cls [Class] used to identify the observer for logging
      def initialize(cls)
        @class = cls

        @observables = []
        @values = {}
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
        raise "unknown observable: #{observable.inspect}" unless @values.has_key? observable
        @values[observable] = value
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

      # Accepting updates from Observables?
      #
      # @return [Boolean] false => delete from Observable#observers
      def alive?
        fail NotImplementedError
      end

      # Accepting calls from Observer?
      #
      # @return [Boolean] false => block calls on updates
      def active?
        fail NotImplementedError
      end

      # Run block or resume task
      def call
        fail NotImplementedError
      end

      class Async < Observe
        # @param block [Block] Observing block
        def initialize(cls, &block)
          super(cls)
          @block = block
          @active = false
        end

        # Persistent, expected to be updated multiple times
        #
        # @return [Boolean]
        def alive?
          true
        end

        # Persistent, expected to be updated multiple times
        #
        # @return [Boolean]
        def active?
          @active
        end

        # All observables have been added, ready for update calls.
        #
        def active!
          @active = true
        end

        def call
          Thread.current[:celluloid_actor].task(:observe) do
            @block.call(*values)
          end
        end
      end

      class Sync < Observe
        def initialize(cls)
          super(cls)
          @task = nil
          @alive = true
        end

        # Expect updates from Observables even when we are not yet waiting.
        #
        # @return [Boolean]
        def alive?
          @alive
        end

        # The observe is callable.
        #
        # @return [Boolean]
        def active?
          !!@task
        end

        # Sets observe as active and suspend task waiting for call()
        #
        # @param timeout [Float, nil]
        # @raise Celluloid::TaskTimeout
        def wait(timeout: nil)
          task = Celluloid::Task.current

          if timeout
            # register an Actor run loop Celluloid::Actor@timers timer
            # the timeout block runs directly in the Actor thread, outside of any task context
            timer = Thread.current[:celluloid_actor].timers.after(timeout) do
              task.resume Celluloid::TaskTimeout.new
            end
          else
            timer = nil
          end

          # suspend task and wait for call()
          @task = task

          wakeup = task.suspend(:observe)

          fail "spurious task wakeup: #{wakeup.inspect}" unless wakeup == self

        ensure
          # no longer expecting call()
          @task = nil
          timer.cancel if timer
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

        # No longer expecting updates.
        #
        def kill
          @alive = false
        end
      end
    end

    # Register handler for Kontena::Observable::Message on the Celluloid::Actor
    #
    def register_observer_handler
      actor = Thread.current[:celluloid_actor]
      actor.observe_handler ||= actor.handle(Kontena::Observable::Message) do |message|
        # This handler runs directly in the Actor thread, outside of any task context.
        handle_observer_message(message)
      end
    end

    # Update the Observe, and call it if ready, which will active the observe task.
    #
    # @param message [Kontena::Observable::Message]
    def handle_observer_message(message)
      observe = message.observe

      if message.observable
        debug "observe update #{message.describe_observable} -> #{message.value}"

        observe.set(message.observable, message.value)
      end

      if !observe.alive?
        debug "observe dead: #{observe.describe_observables}"
      elsif !observe.active?
        debug "observe inactive: #{observe.describe_observables}"
      elsif observe.ready?
        debug "observe ready: #{observe.describe_observables}"

        observe.call
      else
        debug "observe blocked: #{observe.describe_observables}"
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
      observe = Observe::Async.new(self.class, &block)

      # sync setup of each observable
      observables.each do |observable|
        # register for observable updates
        # this MUST be atomic with the Observe#add, there cannot be any observe update message in between!
        message = observable.add_observer(actor.mailbox, observe)

        if message.value
          debug "observe async #{message.describe_observable} => #{message.value}"

          observe.add(message.observable, message.value)
        else
          debug "observe async #{message.describe_observable}..."

          observe.add(message.observable)
        end

        # crash if observed Actor crashes, otherwise we get stuck without updates
        # this is not a bidrectional link: our crashes do not propagate to the observable
        self.monitor observable
      end

      # all observables have been added, ready to begin accepting updates
      observe.active!

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
      observe = Observe::Sync.new(self.class)

      observables.each do |observable|
        # query for initial Observable state, and subscribe for updates if not yet ready
        # this MUST be atomic with the Observe#add, there cannot be any observe update message in between!
        message = observable.add_observer(actor.mailbox, observe, persistent: false)

        if message.value
          debug "observe sync #{message.describe_observable} => #{message.value}"

          observe.add(message.observable, message.value)

        else
          debug "observe sync #{message.describe_observable}..."

          observe.add(message.observable)
        end
      end

      if observe.ready?
        debug "observe sync #{observe.describe_observables}: #{observe.values.join(', ')}"
      else
        debug "observe wait #{observe.describe_observables}... (timeout=#{timeout})"

        begin
          observe.wait(timeout: timeout)
        rescue Celluloid::TaskTimeout
          raise Timeout::Error, "observe timeout #{'%.2fs' % timeout}: #{observe.describe_observables}"
        end

        debug "observe wait #{observe.describe_observables}: #{observe.values.join(', ')}"
      end

      if observables.length == 1
        return observe.values.first
      else
        return observe.values
      end
    ensure
      observe.kill if observe
    end
  end
end
