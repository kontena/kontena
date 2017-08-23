#!/usr/bin/env ruby

require_relative './benchmark-support'

class TestClient
  include Celluloid
  include Kontena::Logging

  DELAY_MIN = getenv('DELAY_MIN', 0.0) {|v| Float(v) }
  DELAY_MAX = getenv('DELAY_MAX', 1.0) {|v| Float(v) }

  def send(id, actor)
    delay = rand() * DELAY_MAX
    delay = 0 if delay < DELAY_MIN

    #debug "request id=#{id} with delay=#{'%.2f' % delay}s"

    if delay > 0
      after(delay) { respond(id, actor) }
    else
      respond(id, actor)
    end
  end

  def respond(id, actor)
    #debug "respond id=#{id}... @ #{caller(0).join("\n\t")}"

    actor.response(id, Time.now)
  end
end

class TestWaiterActor
  include Celluloid
  include Kontena::Helpers::WaitHelper

  def initialize(client)
    @client = client
    @requests = {}
  end

  # @return [Float] response delay
  def request(id, timeout: 30.0)
    @requests[id] = nil

    @client.send(id, self.current_actor)

    wait_until!("request has response with id=#{id}", timeout: timeout, interval: 0.01) { @requests[id] }

    t = @requests.delete(id)

    return Time.now - t
  end

  def response(id, t)
    #debug "response id=#{id}"

    @requests[id] = t
  end
end

class TestConditionActor
  include Celluloid
  include Kontena::Helpers::WaitHelper

  def initialize(client)
    @client = client
    @requests = {}
  end

  # @return [Float] response delay
  def request(id, timeout: 30.0)
    condition = @requests[id] = Celluloid::Condition.new

    @client.send(id, self.current_actor)

    condition.wait(timeout)

    t = @requests.delete(id)

    return Time.now - t
  end

  def response(id, t)
    if cond = @requests[id]
      @requests[id] = t
      cond.signal
    end
  end
end

class TestObserverActor
  include Celluloid
  include Kontena::Observer

  class RequestObservable
    include Kontena::Observable
  end

  def initialize(client)
    @client = client
    @requests = {}
  end

  # @return [Float] response delay
  def request(id, timeout: 30.0)
    observable = @requests[id] = RequestObservable.new

    @client.send(id, self.current_actor)

    t = observe(observable, timeout: timeout)

    return Time.now - t
  end

  def response(id, t)
    @requests.delete(id).update_observable(t)
  end
end

test_client = TestClient.new
test_wait = TestWaiterActor.new(test_client)
test_condition = TestConditionActor.new(test_client)
test_observer = TestObserverActor.new(test_client)

benchmark(
  'wait'      => ->(id) { test_wait.future.request(id) },
  'condition' => ->(id) { test_condition.future.request(id) },
  'observer'  => ->(id) { test_observer.future.request(id) },
)
