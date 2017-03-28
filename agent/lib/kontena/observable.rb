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
    # Updates to value will send to update_observe on given actor.
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
          observer.async.update_observe(observe, Celluloid.current_actor, @value)
        rescue Celluloid::DeadActorError => error
          observers.delete(observe)
        end
      end
    end
  end
end
