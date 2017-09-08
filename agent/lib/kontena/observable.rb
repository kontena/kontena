module Kontena
  # The observable value is nil when initialized, and Observers will wait for it to become ready.
  # Once the observable is first updated, then Observers will return/yield the initial value.
  # When the observable is later updated, Observers will return/yield the updated value.
  # If the observable already has a value, then observing that value will return/yield the immediate value.
  # If the observable crashes, then any Observers will immediately raise.
  #
  # TODO: are you allowed to reset an observable after crashing it, allowing observers to restart and re-observe?
  #
  # @attr observers [Hash{Kontena::Observer => Boolean}] stored value is the persistent? flag
  class Observable
    require_relative './observable/registry'

    # @return [Celluloid::Proxy::Cell<Kontena::Observable::Registry>] system registry actor
    def self.registry
      Celluloid::Actor[:observable_registry] || fail(Celluloid::DeadActorError, "Observable registry actor not running")
    end

    include Kontena::Logging

    attr_reader :logging_prefix # customize Kontena::Logging#logging_prefix by instance

    class Message
      attr_reader :observer, :observable, :value

      # @param observer [Kontena::Observer]
      # @param observable [Kontena::Observable]
      # @param value [Object, nil, Exception]
      def initialize(observer, observable, value)
        @observer = observer
        @observable = observable
        @value = value
      end
    end

    # mixin for Celluloid actor classes
    module Helper
      # Create a new Observable using the including class name as the subject.
      # Register the Observable with the Kontena::Observable::Registry.
      # Links to the registry to crash the Observable if the owning actor crashes.
      #
      # @return [Kontena::Observable]
      def observable
        return @observable if @observable

        # the register can suspend this task, so other calls might get the observable before it gets registered
        # shouldn't be a problem, unless the register/linking somehow fails and crashes this actor without crashing the
        # observable?
        @observable = Kontena::Observable.new(self.class.name)

        observable_registry = Kontena::Observable.registry
        observable_registry.register(@observable, self.current_actor)

        self.links << observable_registry # registry monitors owner

        @observable
      end
    end

    # @param subject [Object] used to identify the Observable for logging purposes
    def initialize(subject = nil)
      @subject = subject
      @mutex = Thread::Mutex.new
      @observers = {}
      @value = nil

      # include the subject (owning actor class, other resource) in log messages
      @logging_prefix = "#{self}"
    end

    # @return [String]
    def to_s
      "#{self.class.name}<#{@subject}>"
    end

    # @return [Object, nil] last updated value, or nil if not ready?
    def get
      @value
    end

    # Observable has updated, and has not reset. It might be crashed?
    #
    # @return [Boolean]
    def ready?
      !!@value
    end

    # Observable has an exception set.
    #
    # Calls to `add_observer` will raise.
    #
    def crashed?
      Exception === @value
    end

    # Observable has observers.
    #
    # NOTE: dead observers will only get cleaned out on the next update
    #
    # @return [Boolean]
    def observed?
      !@observers.empty?
    end

    # The Observable has a value. Propagate it to any observers.
    #
    # This will notify any Observers, causing them to yield/return if ready.
    #
    # The value must be immutable and threadsafe: it must remain valid for use by other threads
    # both after this update, and after any other future updates. Do not send a mutable object
    # that gets invalidated in between updates.
    #
    # TODO: automatically freeze the value?
    #
    # @param value [Object]
    # @raise [RuntimeError] Observable crashed
    # @raise [ArgumentError] Update with nil value
    def update(value)
      raise RuntimeError, "Observable crashed: #{@value}" if crashed?
      raise ArgumentError, "Update with nil value" if value.nil?

      debug { "update: #{value}" }

      set_and_notify(value)
    end

    # Reset the observable value back into the initialized state.
    # This will notify any Observers, causing them to wait until we update again.
    #
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

    # Observer is observing this Observable's value.
    # Raises if observable has crashed.
    # Returns current value, or nil if not yet ready.
    # Subscribes observer for updates if persistent, or if not yet ready (returning nil).
    #
    # The observer will be dropped once no longer alive?.
    #
    # @param observer [Kontena::Observer]
    # @param persistent [Boolean] false => either return immediate value, or return nil and subscribe for a single notification
    # @raise [Exception]
    # @return [Object, nil] current value if ready
    def add_observer(observer, persistent: true)
      @mutex.synchronize do
        if !@value
          # subscribe for future udpates, no value to return
          @observers[observer] = persistent

        elsif Exception === @value
          # raise with immediate value, no future updates to subscribe to
          raise @value

        elsif persistent
          # return with immediate value, also subscribe for future updates
          @observers[observer] = persistent

        else
          # return with immediate value, do not subscribe for future updates
        end

        return @value
      end
    end

    # Send Message with given value to each Kontena::Observer that is still alive.
    # Future calls to `add_observer` will also return the same value.
    # Drops any observers that are dead or non-persistent.
    #
    # TODO: automatically clean out all observers when the observable crashes?
    #
    # @param value [Object, nil, Exception]
    def set_and_notify(value)
      @mutex.synchronize do
        @value = value

        @observers.each do |observer, persistent|
          if !observer.alive?
            debug { "dead: #{observer}" }

            @observers.delete(observer)

          elsif !persistent
            debug { "notify and drop: #{observer} <- #{value}" }

            observer << Message.new(observer, self, value)

            @observers.delete(observer)

          else
            debug { "notify: #{observer} <- #{value}" }

            observer << Message.new(observer, self, value)
          end
        end
      end
    end
  end
end
