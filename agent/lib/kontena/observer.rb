module Kontena
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
    def update_observe(observe, observable, value)
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
        # register for async.update_observe(...)
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
