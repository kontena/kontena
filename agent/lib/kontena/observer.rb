module Kontena
  # An Actor that observes the value of other Obervable Actors
  module Observer
    include Kontena::Logging

    # Observer is observing some Observables, and tracking their values.
    # This object is passed to each Observer, which then passes it back to us for updates.
    class Observe
      # @param observable [Celluloid::Proxy::Cell<Observable>, Observable]
      # @return [Observable]
      def unwrap_observable(observable)
        # XXX: is_a? doesn't work?
        observable.is_a?(Celluloid::Proxy::Cell) ? observable.wrapped_object : observable
      end

      # @param cls [Class] used to identify the observer for logging
      # @param observables [Array<Observable>] Observable objects (NOT PROXIES)
      # @param task [Celluloid::Task] Observing task
      # @param block [Block] Observing block
      def initialize(cls, observables, task = nil, &block)
        @class = cls
        @observables = observables #XXX .map{|observable| unwrap_observable(observable) }
        @task = task
        @block = block
        @values = Hash[@observables.map{|observable| [observable, nil]}]

        $stderr.puts "@values=#{@values.inspect}"
      end

      # For debugging purposes...
      #
      # @return [Array<String>]
      def observables
        @observables.map{|observable| observable.class.name}
      end

      # Called by the Observer actor for logging
      # Must be threadsafe and local
      def to_s
        "Observer<#{@class.name}>"
      end

      # Set value for observable
      #
      # @raise [RuntimeError]
      # @return value
      def set(observable, value)
        #XXX observable = unwrap_observable(observable)
        raise "unknown observable: #{observable}" unless @values.has_key? observable
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

      # Yield to block with values
      def call
        if @block
          @block.call(*values)
        elsif @task
          @task.resume(self)
        else
          abort
        end
      end
    end

    # Observe has been updated, call if ready.
    # Called from observe as an async task.
    #
    # @param observe [Observer::Observe]
    def observed(observe)
      observe.call if observe.ready?
    end

    # Called from Observable as an async task.
    #
    # @param observe [Observer::Observe]
    # @param observable [Celluloid::Proxy::Cell<Observable>]
    # @param value [Object, nil] observed value
    def update_observe(observe, observable, value)
      debug "observe Observable<#{observable.__klass__}> -> #{value}"

      observe.set(observable, value)
      observed(observe)
    end

    # Register celluloid actor handler for Kontena::Observable::Message.
    #
    # Updates the Observe, and calls if ready.
    def register_observer_handler
      @observer_handler ||= Thread.current[:celluloid_actor].handle(Kontena::Observable::Message) do |message|
        debug "observe Observable<#{message.observable.class.name}> -> #{message.value}"

        observe = message.observe
        observe.set(message.observable, message.value)
        observe.call if observe.ready?
      end
    end

    # Observe values from Observables, yielding each value to block.
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
    def observe(*observables, &block)
      # unique handle to identify this observe loop
      observe = Observe.new(self.class, observables, &block)

      # sync setup of each observable
      observables.each do |observable|
        # register for async.update_observe(...)
        value = observable.add_observer(Celluloid.current_actor, observe)

        if value
          # store value for initial call, or nil to block
          observe.set(observable, value)

          debug "observe Observable<#{observable.__klass__}> = #{value}"
        else
          debug "observe Observable<#{observable.__klass__}>..."
        end

        # crash if observed Actor crashes, otherwise we get stuck without updates
        # this is not a bidrectional link: our crashes do not propagate to the observable
        self.monitor observable
      end

      # immediate async update if all observables were ready
      async.observed(observe)

      observe
    end

    # Blocking observe.
    #
    # This suspends the current celluloid actor task if the observable is not yet ready.
    #
    # @param observable [Observable]
    # @param timeout [Float] optional timeout in seconds
    # @raise [Timeout::Error]
    # @return [Object]
    def wait_observable!(*observables, timeout: nil)
      self.register_observer_handler

      actor = Celluloid.current_actor
      task = Celluloid::Task.current
      observe = Observe.new(self.class, observables.map{|proxy| proxy.wrapped_object}, task)

      observables.each do |observable|
        if value = observable.add_waiter(Celluloid.current_actor, observe)
          debug "wait Observable<#{observable.__klass__}> = #{value}"

          observe.set(observable.wrapped_object, value)
        else
          debug "wait Observable<#{observable.__klass__}>..."
        end
      end

      unless observe.ready?
        debug "wait Observable<#{observe.observables.join(', ')}>... (timeout=#{timeout})"

        Thread.current[:celluloid_actor].timeout(timeout) do
          begin
            wakeup = task.suspend(:observe)
          rescue Celluloid::TaskTimeout => exc
            raise Timeout::Error, "timeout after waiting #{'%.2fs' % timeout} until: Observable<#{observe.observables.join(', ')}>"
          end

          fail "spurious task wakeup: #{wakeup.inspect}" unless wakeup == observe
        end
      end

      debug "wait Observable<#{observe.observables.join(', ')}> -> #{observe.values.join(', ')}"

      if observables.length == 1
        return observe.values.first
      else
        return observe.values
      end
    end
  end
end
