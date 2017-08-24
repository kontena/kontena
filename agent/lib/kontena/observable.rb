module Kontena
  # The value does not yet exist when initialized, it is nil.
  # Once the value is first updated, then other Actors will be able to observe it.
  # When the value later updated, observing Actors will be notified of those changes.
  #
  # @attr observers [Hash{Kontena::Observer::Observe => Celluloid::Proxy::Cell}]
  class Observable
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
    end

    def initialize
      @mutex = Thread::Mutex.new
      @observers = {}
      @value = nil
    end

    # @return [String]
    def to_s
      "#{self.class.name}"
    end

    # @return [Object, nil] last updated value, or nil if not observable?
    def get
      @value
    end

    # Observable has updated, and has not reset
    #
    # @return [Boolean]
    def observable?
      !!@value
    end

    # Observable has observers
    #
    # @return [Boolean]
    def observed?
      !@observers.empty?
    end

    # The Observable has a value. Propagate it to any observing Actors.
    #
    # This will notify any Observers, causing them to yield if ready.
    #
    # The value must be safe for access by multiple threads, even after this update,
    # and even after any later updates.
    #
    # TODO: automatically freeze the value?
    #
    # @param value [Object]
    # @raise [ArgumentError] Update with nil value
    def update(value)
      raise ArgumentError, "Update with nil value" if value.nil?

      debug { "update: #{value}" }

      set_and_notify(value)
    end

    # Reset the observable value back into the initialized stte.
    # This will notify any Observers, causing them to block until we update again.
    def reset
      debug { "reset" }

      set_and_notify(nil)
    end

    # Observer actor is observing this Actor's @observable_value.
    # Subscribes actor for updates to our observable value, sending Kontena::Observable::Message to given actor.mailbox.
    # Links actor, such that observable actor crashes propagate to the observer.
    # Returns Kontena::Observable::Message with current value.
    # The observing actor will be unsubscribed/unlinked once the actor.mailbox or observe becomes !alive?.
    #
    # @param observe [Observer::Observe]
    # @param actor [Celluloid::Proxy::Cell<Actor>]
    # @return [Object] current value
    def observe(observe, actor)
      @mutex.synchronize do
        if !@value
          # subscribe for future udpates, no value to return
          debug { "observer: #{observe}..." }

          @observers[observe] = actor

        elsif observe.persistent?
          # return with immediate value, also subscribe for future updates
          debug { "observer: #{observe} <= #{@value.inspect[0..64]}..." }

          @observers[observe] = actor
        else
          # return with immediate value, do not subscribe for future updates
          debug { "observer: #{observe} <= #{@value.inspect[0..64]}" }
        end

        return @value
      end
    end

    # Update @value to each Kontena::Observer::Observe
    def set_and_notify(value)
      @mutex.synchronize do
        @value = value

        @observers.each do |observe, actor|
          if alive = observe.alive? && actor.mailbox.alive?
            debug { "notify: #{observe} <- #{value.inspect[0..64]}" }

            actor.mailbox << Message.new(observe, self, value)
          end

          unless alive && observe.persistent?
            debug { "drop: #{observe}" }

            @observers.delete(observe)
          end
        end
      end
    end
  end
end
