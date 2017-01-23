module Kontena::Actors
  class Observable
    include Celluloid
    include Kontena::Logging

    def initialize
      @observers = {}
      @value = nil

      debug "initialize"
    end

    def update(value)
      debug "update: #{value}"

      @value = value

      notify(@value)
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
    # Set instance attributes from observables
    # Yields to block once all obsered instance attributes are valid, and when they are updated
    # @param observables [Hash{Symbol => Observable}]
    # @yield [] all observable attributes are valid
    def observe(**observables, &block)
      # invoke block when all observables are ready
      update_proc = Proc.new do
        block.call if block unless observables.any? { |sym, observable| instance_variable_get("@#{sym}").nil? }
      end

      observables.each do |sym, observable|
        # update state for observable, and run update block
        define_singleton_method("#{sym}=") do |value|
          instance_variable_set("@#{sym}", value)
          update_proc.call()
        end

        if value = observable.observe(Celluloid.current_actor, "#{sym}=")
          # update initial state; only run update block once at end
          instance_variable_set("@#{sym}", value)
        end
      end

      # immediately run update block if all observables were ready
      update_proc.call()
    end
  end
end
