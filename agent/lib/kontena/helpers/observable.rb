module Kontena
  # An Actor that has some value
  # The value does not yet exist when initialized, it is nil
  # Once the value is first updated, then other Actors will be able to observe it
  # When the value later updated, other Actors will also observe those changes
  module Observable
    include Kontena::Logging

    # Update from Observable to Observer::State handle with value
    class Message
      attr_reader :observable, :state, :value

      def initialize(observable, state, value)
        @observable = observable
        @state = state
        @value = value
      end

      # XXX: avoid any remote inspect or to_s calls on these actors when formatting for for an exception
      def to_s
        "#{self.class.name}<observable: @#{@observable.object_id}, state: @#{@state.object_id}, value: #{@value.inspect}>"
      end
    end

    def value
      @value
    end

    def observers
      @observers ||= {}
    end

    def update(value)
      debug "update: #{value}"

      @value = value

      notify_observers
    end

    # Remote actor is observing this Actor's @value
    # Updates to value will send to async method on given actor
    # Returns current value
    #
    # @param actor [celluloid::Actor]
    # @param method [Symbol]
    # @return [Object, nil] possible existing value
    def add_observer(observer, state)
      debug "observer: #{observer} <- #{@value.inspect[0..64] + '...'}"

      observers[observer] = state

      return @value
    end

    def notify_observers
      observers.each do |observer, state|
        begin
          debug "notify: #{observer} <- #{@value}"

          observer.mailbox << Message.new(Celluloid.current_actor, state, @value)
        rescue Celluloid::DeadActorError => error
          observers.delete(actor)
        end
      end
    end
  end

  # An Actor that observes the value of other Obervable Actors
  module Observer
    include Kontena::Logging

    # Yield values from Observables.
    # Yields to block once all observed values are valid, and when they are updated.
    # Crashes this Actor if any of the observed Actors crashes.
    # XXX: this is a blocking call, which does not return
    #
    # @param observables [Array{Observable}]
    # @yield [] all observables are valid
    def observe(*observables, &block)
      # this acts as a unique handle to identify this observe loop
      state = {}

      # setup
      observables.each do |observable|
        value = state[observable] = observable.add_observer(Celluloid.current_actor, state)

        debug "observe #{observable} -> #{value}"

        # crash if observed Actor crashes, otherwise we get stuck
        self.link observable
      end

      loop do
        values = observables.map{|observable| state[observable] }

        # invoke block if all observables are ready
        yield(*values) unless values.any? { |value| value.nil? }

        # message loop to update state
        message = receive { |message| message.is_a?(Observable::Message) && message.state.equal?(state) }

        # XXX: is the Observable's Celluloid.current_actor guranteed to match the Actor[:node_info_worker] Celluloid::Proxy::Cell by identity?
        state[message.observable] = message.value

        debug "observe #{message.observable} -> #{message.value}"
      end
    end
  end
end
