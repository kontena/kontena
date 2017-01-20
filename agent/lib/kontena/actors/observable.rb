module Kontena::Actors
  class Observable
    include Celluloid
    include Kontena::Helpers::WaitHelper
    include Kontena::Logging

    # @param subscribe [String] update from Celluloid notifications
    def initialize(subscribe: nil)
      @observers = {}
      @value = nil

      if subscribe
        self.extend Celluloid::Notifications
        self.subscribe(subscribe, :update)
      end
    end

    def update(value)
      debug "update: #{value}"

      @value = value

      notify(@value)
    end

    def get
      wait { @value }
    end

    # Send to actor async method on update
    # Return if updated
    #
    # @param actor [celluloid::Actor]
    # @param method [Symbol]
    # @return [Object, nil] value
    def observe(actor, method)
      debug "observe: #{actor}.#{method}"

      @observers[actor] = method

      return @value
    end

    def notify(value)
      @observers.each do |actor, method|
        begin
          debug "notify: #{actor}.#{method}: #{value}"

          actor.async method, value
        rescue Celluloid::DeadActorError => error
          @observers.delete(actor)
        end
      end
    end
  end

  module Observer
    def observe(observable, method)
      observable.observe(Celluloid.current_actor, method)
    end
  end
end
