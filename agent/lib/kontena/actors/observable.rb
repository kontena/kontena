module Kontena::Actors
  class Observable
    include Celluloid
    include Kontena::Helpers::WaitHelper
    include Kontena::Logging

    def initialize(&block)
      @observers = {}
      @value = nil
      @block = block
    end

    def update(value)
      debug "update: #{value}"

      @value = value.freeze

      notify(@value)
    end

    def get
      wait { @value }
    end

    # Send to actor async method on update

    # @param actor [celluloid::Actor]
    # @param method [Symbol]
    def observe(actor, method)
      debug "observe: #{actor}.#{method}"

      if @value
        actor.sync method, @value
      end

      @observers[actor] = method
    end

    def notify(value)
      @observers.each do |actor, method|
        begin
          actor.async method, value
        rescue Celluloid::DeadActorError => error
          @observers.delete(actor)
        end
      end
    end
  end
end
