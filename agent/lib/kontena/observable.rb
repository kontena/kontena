module Kontena
  # The value does not yet exist when initialized, it is nil.
  # Once the value is first updated, then other Actors will be able to observe it.
  # When the value later updated, observing Actors will be notified of those changes.
  #
  # @attr observers [Hash{Kontena::Observer::Observe => Celluloid::Proxy::Cell}]
  class Observable
    include Kontena::Logging

    attr_reader :logging_prefix

    def self.registry
      Celluloid::Actor[:observable_registry] || fail(DeadActorError, "Observable registry actor not running")
    end

    class Registry
      include Celluloid
      include Kontena::Logging

      trap_exit :on_actor_crash

      def initialize
        info 'initialize'

        @observables = {}
      end

      def register(observable, actor)
        @observables[observable] = actor

        debug "register #{observable}: #{actor.__klass__}"
      end

      def on_actor_crash(actor, reason)
        debug "crash #{actor.__klass__}: #{reason}"

        @observables.each_pair do |observable, observable_actor|
          if observable_actor == actor
            debug "crash #{observable}..."

            observable.crash(reason)
          end
        end
      end
    end

    class Message
      attr_reader :observe, :observable, :value

      # @param observe [Kontena::Observable::Observe]
      # @param observable [Kontena::Observable]
      # @param value [Object, nil, Exception]
      def initialize(observe, observable, value)
        @observe = observe
        @observable = observable
        @value = value
      end
    end

    # @return [Kontena::Observable]
    def self.register(owner = Celluloid.current_actor, owner_links = Celluloid.links)
      observable = self.new(owner.__klass__)

      observable_registry = self.registry
      observable_registry.register(observable, owner)
      owner_links << observable_registry # registry monitors owner

      observable
    end

    def initialize(owner_name = Celluloid.current_actor.__klass__)
      @owner_name = owner_name
      @mutex = Thread::Mutex.new
      @observers = {}
      @value = nil

      # include the name of the owning class in log messages
      @logging_prefix = "#{self}"
    end

    # @return [String]
    def to_s
      "#{self.class.name}<#{@owner_name}>"
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

    def crashed?
      Exception === @value
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
      raise RuntimeError, "Observable crashed: #{@value}" if crashed?
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

    # @param reason [Exception]
    def crash(reason)
      raise ArgumentError, "Crash with non-exception: #{reason.class.name}" unless Exception === reason

      debug { "crash: #{reason}" }

      set_and_notify(reason)
    end

    # Observer actor is observing this Actor's @observable_value.
    # Subscribes actor for updates to our observable value, sending Kontena::Observable::Message to given actor.mailbox.
    # Links actor, such that observable actor crashes propagate to the observer.
    # Returns Kontena::Observable::Message with current value.
    # The observing actor will be unsubscribed/unlinked once the actor.mailbox or observe becomes !alive?.
    #
    # @param observe [Observer::Observe]
    # @param actor [Celluloid::Proxy::Cell<Actor>]
    # @raise [Exception]
    # @return [Object] current value
    def observe(observe, actor)
      @mutex.synchronize do
        if !@value
          # subscribe for future udpates, no value to return
          @observers[observe] = actor

        elsif Exception === @value
          # raise with immediate value, no future updates to subscribe to
          raise @value

        elsif observe.persistent?
          # return with immediate value, also subscribe for future updates
          @observers[observe] = actor

        else
          # return with immediate value, do not subscribe for future updates
        end

        return @value
      end
    end

    # Update @value to each Kontena::Observer::Observe
    #
    # @param value [Object, nil, Exception]
    def set_and_notify(value)
      @mutex.synchronize do
        @value = value

        @observers.each do |observe, actor|
          alive = observe.alive? && actor.mailbox.alive?

          if !alive
            debug { "dead: #{observe}" }

            @observers.delete(observe)

          elsif !observe.persistent?
            debug { "notify and drop: #{observe} <- #{value}" }

            actor.mailbox << Message.new(observe, self, value)

            @observers.delete(observe)

          else
            debug { "notify: #{observe} <- #{value}" }

            actor.mailbox << Message.new(observe, self, value)
          end
        end
      end
    end
  end
end

class Celluloid::Actor::System
  ROOT_SERVICES << {
    as: :observable_registry,
    type: Kontena::Observable::Registry,
  }
end
