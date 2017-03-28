module Kontena
  # An Actor that has some value
  # The value does not yet exist when initialized, it is nil
  # Once the value is first updated, then other Actors will be able to observe it
  # When the value later updated, other Actors will also observe those changes
  module Observable
    include Kontena::Logging

    def value
      @value
    end

    # Registered Observers
    #
    # @return [Hash{Observe => Celluloid::Proxy::Cell<Observer>}]
    def observers
      @observers ||= {}
    end

    # The Observable has a value.
    #
    # This will notify any Observers, causing them to yield if ready.
    #
    # @param value [Object]
    # @raise [ArgumentError] Update with nil value
    def update(value)
      raise ArgumentError, "Update with nil value" if value.nil?
      debug "update: #{value}"

      @value = value

      notify_observers
    end

    # The Observable no longer has a value
    # This will notify any Observers, causing them to block yields until we update again
    def reset
      @value = nil

      notify_observers
    end

    # Observer actor is observing this Actor's @value.
    # Updates to value will send to update_observed on given actor.
    # Returns current value.
    #
    # @param observer [Celluloid::Proxy::Cell<Observer>]
    # @param observe [Observer::Observe]
    # @return [Object, nil] possible existing value
    def add_observer(observer, observe)
      debug "observer: #{observer} <- #{@value.inspect[0..64] + '...'}"

      observers[observe] = observer

      return @value
    end

    # Update @value to each Observer::Observe
    def notify_observers
      observers.each do |observe, observer|
        begin
          debug "notify: #{observer} <- #{@value}"

          # XXX: is the Observable's Celluloid.current_actor guranteed to match the Actor[:node_info_worker] Celluloid::Proxy::Cell by identity?
          observer.async.update_observed(observe, Celluloid.current_actor, @value)
        rescue Celluloid::DeadActorError => error
          observers.delete(observe)
        end
      end
    end
  end

  # An Actor that observes the value of other Obervable Actors
  module Observer
    include Kontena::Logging

    # Observer is observing some Observables, and tracking their values.
    # This object is passed to each Observer, which then passes it back to us for updates.
    class Observe
      # @param observables [Array<Observable>] Observable actors
      # @param block [Block] Observing block
      def initialize(observables, block)
        @observables = observables
        @block = block
        @values = { }
      end

      # Set value for observable
      #
      # @return value
      def set(observable, value)
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
        @block.call(*values)
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
    def update_observed(observe, observable, value)
      observe.set(observable, value)
      observed(observe)
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
    # Setup happens sync, and will raise on invalid observables.
    # Crashes this Actor if any of the observed Actors crashes.
    #
    # @param observables [Array<Celluloid::Proxy::Cell<Observable>>]
    # @raise failed to observe observables
    # @return [Observer::Observe]
    # @yield [*values] all Observables are ready
    def observe(*observables, &block)
      # unique handle to identify this observe loop
      observe = Observe.new(observables, block)

      # sync setup of each observable
      observables.each do |observable|
        # register for async.update_observed(...)
        value = observable.add_observer(Celluloid.current_actor, observe)

        # store value for initial call, or nil to block
        observe.set(observable, value)

        debug "observe #{observable} -> #{value}"

        # crash if observed Actor crashes, otherwise we get stuck without updates
        # this is not a bidrectional link: our crashes do not propagate to the observable
        self.monitor observable
      end

      # immediate async update if all observables were ready
      async.observed(observe)

      observe
    end
  end
end
