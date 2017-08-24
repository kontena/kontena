#!/usr/bin/env ruby

require_relative './benchmark-support'

class TestActor
  include Celluloid

  DELAY = getenv('START_DELAY', 1.0) { |x| Float(x) }

  attr_reader :observable

  def initialize
    @observable = Kontena::Observable.new
  end

  def reset
    @ready = nil
    @observable.reset
  end

  def start(delay: DELAY)
    sleep delay
    @ready = Time.now
    @observable.update @ready
  end

  def ready?
    @ready
  end
end

class TestObserverActor
  include Celluloid
  include Kontena::Observer

  def initialize(observable)
    @observable = observable
  end

  def watch
    ready = observe(@observable)
    Time.now - ready
  end
end

class TestWaitActor
  include Celluloid
  include Kontena::Helpers::WaitHelper

  WAIT_INTERVAL = getenv("WAIT_INTERVAL", 0.01) { |v| Float(v) }

  def initialize(actor)
    @actor = actor
  end

  def watch
    ready = wait_until!("observable ready", interval: WAIT_INTERVAL) { @actor.ready? }
    Time.now - ready
  end
end

test_actor = nil
test_observable = nil

benchmark(
  {
    'wait'      => ->(id) { TestWaitActor.new(test_actor).future.watch },
    'observer'  => ->(id) { TestObserverActor.new(test_observable).future.watch },
  },
  before_each: ->() {
    test_actor = TestActor.new()
    test_actor.async.start
    test_observable = test_actor.observable
  },
)
