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

    def observers
      @observers ||= {}
    end

    # The Observable has a value
    # This will notify any Observers, causing them to yield if ready
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

    # Remote actor is observing this Actor's @value
    # Updates to value will send to async method on given actor
    # Returns current value
    #
    # @param observer [Observer]
    # @param observe [Observer::Observe]
    # @return [Object, nil] possible existing value
    def add_observer(observer, observe)
      debug "observer: #{observer} <- #{@value.inspect[0..64] + '...'}"

      observers[observe] = observer

      return @value
    end

    def notify_observers
      observers.each do |observe, observer|
        begin
          debug "notify: #{observer} <- #{@value}"

          # XXX: is the Observable's Celluloid.current_actor guranteed to match the Actor[:node_info_worker] Celluloid::Proxy::Cell by identity?
          observer.async.update_observed(observe, Celluloid.current_actor, @value)
        rescue Celluloid::DeadActorError => error
          observers.delete(actor)
        end
      end
    end
  end

  # An Actor that observes the value of other Obervable Actors
  module Observer
    include Kontena::Logging

    # A task observing some Observables, and tracking their values
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

    def observed(observe)
      observe.call if observe.ready?
    end

    # Called by Observable
    # @param observe [Observer::Observe]
    # @param observable [Observable] actor
    # @param value [Object, nil] observed value
    def update_observed(observe, observable, value)
      observe.set(observable, value)
      observed(observe)
    end

    # Yield values from Observables.
    # Yields to block once all observed values are valid, and when they are updated.
    # Crashes this Actor if any of the observed Actors crashes.
    #
    # Yields to block from new async task. Setup happens sync, and will raise on broken observables
    #
    # @param observables [Array{Observable}]
    # @return [Observe]
    # @yield [] all observables are valid
    def observe(*observables, &block)
      # unique handle to identify this observe loop
      observe = Observe.new(observables, block)

      # sync setup of each observable
      observables.each do |observable|
        # register for async.update_observed(...)
        value = observe.set(observable, observable.add_observer(Celluloid.current_actor, observe))

        debug "observe #{observable} -> #{value}"

        # crash if observed Actor crashes, otherwise we get stuck without updates
        self.link observable
      end

      # do not wait for update if observables were all ready
      async.observed(observe)

      observe
    end
  end
end
