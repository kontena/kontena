#!/usr/bin/env ruby

require_relative './benchmark-support'

class TestObservableActor
  include Celluloid
  include Kontena::Observable::Helper

  DELAY = getenv('START_DELAY', 1.0) { |x| Float(x) }

  def reset
    @ready = nil
    observable.reset
  end

  def start(delay: DELAY)
    sleep delay
    @ready = Time.now
    observable.update @ready
  end

  def ready?
    @ready
  end
end

class TestObserverActor
  include Celluloid
  include Kontena::Observer::Helper
  include Kontena::Helpers::WaitHelper

  WAIT_INTERVAL = getenv("WAIT_INTERVAL", 0.01) { |v| Float(v) }

  def test_observe(observable)
    ready = observe(observable)
    Time.now - ready
  end

  def test_wait(actor)
    ready = wait_until!("observable ready", interval: WAIT_INTERVAL) { actor.ready? }
    Time.now - ready
  end
end

COUNT = getenv('COUNT', 1000) { |v| Integer(v) }

supervise_registry = Kontena::Observable::Registry.supervise :as => :observable_registry
test_actor = TestObservableActor.new
test_observable = test_actor.observable
test_actors = (1..COUNT).map{ TestObserverActor.new }

benchmark(
  {
    'wait'      => -> {
      map_futures(test_actors) {|actor| actor.future.test_wait(test_actor) }
    },
    'observer'  => -> {
      map_futures(test_actors) {|actor| actor.future.test_observe(test_observable) }
    },
  },
  before_each: ->() {
    test_actor.reset
    test_actor.async.start
  },
)
