# Actors can register their Observables to the registry.
# The observable registry is responsible for crashing the Observables if the owning actor crashes.
# This guarantees that Observers receive an error instead of timing out if the observed actor crashes.
class Kontena::Observable::Registry
  include Celluloid
  include Kontena::Logging

  trap_exit :on_actor_crash

  def initialize
    info 'initialized'

    @observables = {}
  end

  def register(observable, actor)
    @observables[observable] = actor

    debug "register #{observable}: #{actor.__klass__}"
  end

  # @param observable [Kontena::Observable]
  # @return [Boolean]
  def registered?(observable)
    @observables.has_key? observable
  end

  def each_observable_for_actor(actor)
    @observables.each_pair do |observable, observable_actor|
      yield observable if observable_actor == actor
    end
  end

  def on_actor_crash(actor, reason)
    if reason.nil?
      # reason is nil if actor terminated cleanly
      reason = Celluloid::DeadActorError.new("Actor terminated")
    end

    warn "crashing observables owned by actor #{actor.__klass__}: #{reason}"

    each_observable_for_actor(actor) do |observable|
      @observables.delete(observable)

      debug "crash #{observable}..."

      observable.crash(reason)
    end
  end
end
