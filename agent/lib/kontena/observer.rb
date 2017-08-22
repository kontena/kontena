class Celluloid::Actor
  attr_accessor :observe_handler
end

module Kontena
  # An Actor that observes the value of other Obervables.
  module Observer
    include Kontena::Logging

    # Observer is observing some Observables, and tracking their values.
    # This object is passed to each Observable, which then sends it back via Kontena::Observable::Message for updates.
    class Observe
      # @param cls [Class] used to identify the observer for logging
      def initialize(cls)
        @class = cls

        @observables = []
        @values = {}
        @pending = false
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
      def describe_observer
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
        pending!
      end

      # @return [Boolean] true => observable has pending changes
      def pending?
        @pending
      end

      # Have pending changes
      def pending!
        @pending = true
      end

      # Rsovle pending changes
      def resolve!
        @pending = false
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

        # Accepting calls?
        #
        # @return [Boolean]
        def active?
          @active
        end

        # All observables have been added, ready for update calls.
        #
        def start!
          @active = true
        end
        def resume!
          @active = true
        end

        # Pause calls.
        #
        def pause!
          @active = false
        end

        def call
          pause! # prevent concurrent calls until task completes
          resolve! # clear @pending state to detect concurrent updates during call

          observed_values = self.values
          Thread.current[:celluloid_actor].task(:observe) do
            begin
              @block.call(*observed_values)
            ensure
              resume! # allow next call

              if pending?
                # values changed during call and were blocked, reschedule
                async_call(Celluloid::Actor.current)
              end
            end
          end
        end

        # Trigger a deferred call of the Observe via the actor mailbox
        #
        # @param actor [Celluloid::Proxy::Cell<Kontena::Observer]
        def async_call(actor)
          actor.mailbox << Kontena::Observable::Message.new(self, nil, nil)
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

        # Suspend task after setting observe as active.
        # Cannot be called in Celluloid.exclusive? mode.
        # Later mailbox -> handle -> call will resume the task
        #
        # @param timeout [Float, nil]
        # @raise Celluloid::TaskTimeout
        # @raise Celluloid::TaskTerminated actor shtudown
        def suspend(task, timeout: nil)
          if timeout
            timer = Thread.current[:celluloid_actor].timers.after(timeout) do
              # the timer block runs directly in the Actor thread, outside of any task context
              # raise TaskTimeout from task.suspend
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
          if task = @task
            fail "observe task is not suspended in observe: #{task.status}" unless task.status == :observe

            # once we've resumed the task, we must not re-resume it, as it will be suspended somewhere else
            @task = nil

            task.resume(self)
          else
            fail "observe is not suspended in any task"
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
        # this handler runs directly in the Actor thread, outside of any task context.
        handle_observer_message(message)
      end
    end

    # Update the Observe, and call it if ready, which will active the observe task.
    # Must be called from Celluloid::Actor#handle directly in the Actor thread.
    # Do not call this from any task context.
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
        debug "observe paused: #{observe.describe_observables}"
      elsif observe.ready?
        debug "observe ready: #{observe.describe_observables}"
        observe.call
      else
        debug "observe blocked: #{observe.describe_observables}"
      end
    end

    # Block thread until mailbox receives update or times out.
    # Must only be called in Celluloid.exclusive? mode.
    # Returns once the observe is ready.
    #
    # @param observe [Observe]
    # @param timeout [Float, nil]
    # @raise Celluloid::TaskTimeout
    def wait_observe(observe, mailbox, timeout: nil)
      deadline = Time.now + timeout if timeout

      while !observe.ready?
        receive_timeout = deadline ? deadline - Time.now : nil

        if receive_timeout && receive_timeout < 0
          raise Celluloid::TaskTimeout.new("wait deadline exceeded")
        end

        message = mailbox.receive(receive_timeout) { |msg|
          Kontena::Observable::Message === msg && msg.observe == observe
        }

        if message.is_a?(Celluloid::SystemEvent)
          debug "observe receive #{msg.class.name}"

          Thread.current[:celluloid_actor].handle_system_event(message)
        else
          debug "observe update #{message.describe_observable} -> #{message.value}"

          observe.set(message.observable, message.value)
        end
      end
    end

    # Observe values from Observables, either synchronously or asynchronously.
    #
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>, Observable>]
    # @param timeout [Float] optional timeout in seconds, only supported for sync mode
    # @see [#observe_async] yields if block is given
    # @see [#observe_sync] returns unless block is given
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
    # Returns the active Observe after subscribing to each Observable, or raises on dead/invalid observables.
    # Yields from an async task once each Observable is ready, and again whenever any observable updates.
    # Crashes this Actor if any of the observed Actors crashes.
    #
    # Does not yield if any Observable resets, until all Observables are ready again.
    # Does not yield if the previous async block task is still running.
    # Yields again after the block returns, if any observables have updated during the execution of the block.
    #
    # The block must be idempotent: it is not guaranteed to receive every Observable update,
    # and it may receive some Observable updates multiple times.
    # It is guaranteed to receive Observable updates in the correct order.
    #
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>, Observable>]
    # @raise [Celluloid::DeadActorError]
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
        message = observable.add_observer(actor, observe)

        if message.value
          debug "observe async #{message.describe_observable} => #{message.value}"

          observe.add(message.observable, message.value)
        else
          debug "observe async #{message.describe_observable}..."

          observe.add(message.observable)
        end
      end

      # all observables have been added, allow block calls on updates
      observe.start!

      if observe.ready?
        debug "observe async #{observe.describe_observables}: #{observe.values.join(', ')}"

        # trigger immediate update if all observables were ready
        observe.async_call(actor)
      else
        debug "observe async #{observe.describe_observables}..."
      end

      observe
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
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>, Observable>]
    # @param timeout [Float] optional timeout in seconds
    # @raise [Timeout::Error]
    # @raise [Celluloid::DeadActorError]
    # @return [*values]
    def observe_sync(*observables, timeout: nil)
      self.register_observer_handler

      actor = Celluloid.current_actor
      observe = Observe::Sync.new(self.class)

      observables.each do |observable|
        # query for initial Observable state, and subscribe for updates
        # this MUST be atomic with the Observe#add, there cannot be any observe update message in between!
        message = observable.add_observer(actor, observe)

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
        begin
          # @see Celluloid#suspend
          task = Thread.current[:celluloid_task]
          if task && !task.exclusive?
            debug "observe wait #{observe.describe_observables}... (suspend timeout=#{timeout})"

            observe.suspend(task, timeout: timeout)
          else
            debug "observe wait #{observe.describe_observables}... (wait timeout=#{timeout})"

            wait_observe(observe, actor.mailbox, timeout: timeout)
          end
        rescue Celluloid::TaskTerminated
          # XXX: just let this re-raise? Happens if the linking Observable crashes and the Observing actor shuts down
          raise Celluloid::DeadActorError, "observe wait terminated: #{observe.describe_observables}"
        rescue Celluloid::TaskTimeout
          raise Timeout::Error, "observe timeout #{'%.2fs' % timeout}: #{observe.describe_observables}"
        end

        debug "observe wait #{observe.describe_observables}: #{observe.values.join(', ')}"
      end

      observe.resolve! # meaningless, do not expect to receive any more updates after killed

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
