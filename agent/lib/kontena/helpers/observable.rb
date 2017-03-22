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

    def update(value)
      debug "update: #{value}"

      @value = value

      observers.each do |actor, method|
        begin
          debug "notify: #{actor}.#{method} #{value}"

          actor.async method, value
        rescue Celluloid::DeadActorError => error
          observers.delete(actor)
        end
      end
    end

    # Remote actor is observing this Actor's @value
    # Updates to value will send to async method on given actor
    # Returns current value
    #
    # @param actor [celluloid::Actor]
    # @param method [Symbol]
    # @return [Object, nil] possible existing value
    def observe(actor, method)
      debug "observe: #{actor}.#{method}"

      observers[actor] = method

      return @value
    end
  end

  # An Actor that observes the value of other Obervable Actors
  # The values of multiple Ovservables are stored as local instance attributes
  module Observer
    # Set instance attributes from multiple observables
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
