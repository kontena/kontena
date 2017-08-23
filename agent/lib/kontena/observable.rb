module Kontena
  # An Actor that has some value
  # The value does not yet exist when initialized, it is nil
  # Once the value is first updated, then other Actors will be able to observe it
  # When the value later updated, other Actors will also observe those changes
  module Observable
    include Kontena::Logging

    class Message
      attr_reader :observe, :observable, :value

      # @param observe [Kontena::Observable::Observe]
      # @param observable [Kontena::Observable]
      # @param value [Object, nil]
      def initialize(observe, observable, value)
        @observe = observe
        @observable = observable
        @value = value
      end

      # @return [String]
      def describe_observable
        "Observable<#{@observable.class.name}>"
      end
    end

    # @return [Object, nil] last updated value, or nil if not observable?
    def observable_value
      @observable_value
    end

    # Obsevable has updated, as has not reset
    # @return [Boolean]
    def observable?
      !!@observable_value
    end

    # Registered observers
    #
    # @return [Hash{Kontena::Observer::Observe => Celluloid::Proxy::Cell}]
    def observers
      @observers ||= {}
    end

    # The Observable has a value. Propagate it to any observing Actors.
    #
    # This will notify any Observers, causing them to yield if ready.
    #
    # The value must be safe for access by multiple threads, even after this update,
    # and even after any later updates. Ideally, it should be immutable (frozen).
    #
    # @param value [Object]
    # @raise [ArgumentError] Update with nil value
    def update_observable(value)
      raise ArgumentError, "Update with nil value" if value.nil?
      debug { "update: #{value}" }

      @observable_value = value

      notify_observers
    end

    # The Observable no longer has a value
    # This will notify any Observers, causing them to block yields until we update again
    def reset_observable
      @observable_value = nil

      notify_observers
    end

    # Observer actor is observing this Actor's @observable_value.
    # Subscribes actor for updates to our observable value, sending Kontena::Observable::Message to given actor.mailbox.
    # Links actor, such that observable actor crashes propagate to the observer.
    # Returns Kontena::Observable::Message with current value.
    # The observing actor will be unsubscribed/unlinked once the actor.mailbox or observe becomes !alive?.
    #
    # @param actor [Celluloid::Proxy::Cell<Actor>]
    # @param observe [Observer::Observe]
    # @return [Kontena::Observable::Message] with current value
    def add_observer(actor, observe)
      if Celluloid.current_actor != actor
        links = Celluloid.links
      end

      if !observable?
        # subscribe for future udpates, no value to return
        debug { "observer: #{observe.describe_observer}..." }

        links << actor if links
        observers[observe] = actor

      elsif observe.persistent?
        # return with immediate value, also subscribe for future updates
        debug { "observer: #{observe.describe_observer} <= #{@observable_value.inspect[0..64]}..." }

        links << actor if links
        observers[observe] = actor
      else
        # return with immediate value, do not subscribe for future updates
        debug { "observer: #{observe.describe_observer} <= #{@observable_value.inspect[0..64]}" }
      end

      return Message.new(observe, self, @observable_value)
    end

    # Update @observable_value to each Kontena::Observer::Observe
    def notify_observers
      observers.each do |observe, actor|
        if alive = observe.alive? && actor.mailbox.alive?
          debug { "notify: #{observe.describe_observer} <- #{@observable_value.inspect[0..64]}" }

          actor.mailbox << Message.new(observe, self, @observable_value)
        end

        unless alive && observe.persistent?
          debug { "drop: #{observe.describe_observer}" }

          observers.delete(observe)
          Celluloid.links.delete(actor)
        end
      end
    end
  end
end
