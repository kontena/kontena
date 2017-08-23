#!/usr/bin/env ruby

require_relative './benchmark-support'

class TestObservableActor
  include Celluloid
  include Kontena::Observable

  DELAY = getenv('START_DELAY', 1.0) { |x| Float(x) }

  def start(delay: DELAY)
    sleep delay
    @ready = Time.now
    update_observable @ready
  end

  def ready?
    @ready
  end
end

class TestObserverActor
  include Celluloid
  include Kontena::Observer

  def watch
    ready = observe(Actor[:test_observable])
    Time.now - ready
  end
end

class TestWaitActor
  include Celluloid
  include Kontena::Helpers::WaitHelper

  WAIT_INTERVAL = getenv("WAIT_INTERVAL", 0.01) { |v| Float(v) }

  def watch
    ready = wait_until!("observable ready", interval: WAIT_INTERVAL) { Actor[:test_observable].ready? }
    Time.now - ready
  end
end


test_observer = TestObserverActor.new
test_wait = TestWaitActor.new

benchmark(
  {
    'wait'      => ->(id) { test_wait.future.watch },
    'observer'  => ->(id) { test_observer.future.watch },
  },
  before_each: ->() {
    test_observable = Celluloid::Actor[:test_observable] = TestObservableActor.new
    test_observable.async.start
  },
)
