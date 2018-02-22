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

  WAIT_INTERVAL = getenv("WAIT_INTERVAL", 0.01) { |v| Float(v) }

  def initialize(client)
    @client = client
    @requests = {}
  end

  # @return [Float] response delay
  def request(id, timeout: 30.0)
    @requests[id] = nil

    @client.send(id, self.current_actor)

    wait_until!("request has response with id=#{id}", timeout: timeout, interval: WAIT_INTERVAL) { @requests[id] }

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
  include Kontena::Observer::Helper

  class RequestObservable < Kontena::Observable

  end

  def initialize(client)
    @client = client
    @requests = {}
  end

  # @return [Float] response delay
  def request(id, timeout: 30.0)
    observable = @requests[id] = RequestObservable.new(id)

    @client.send(id, self.current_actor)

    t = observe(observable, timeout: timeout)

    return Time.now - t
  end

  def response(id, t)
    @requests.delete(id).update(t)
  end
end

class TestFutureActor
  include Celluloid
  include Kontena::Observer::Helper

  class Response
    attr_reader :value

    def initialize(value)
      @value = value
    end
  end

  def initialize(client)
    @client = client
    @requests = {}
  end

  # @return [Float] response delay
  def request(id, timeout: 30.0)
    future = @requests[id] = Celluloid::Future.new

    @client.send(id, self.current_actor)

    t = future.value

    return Time.now - t
  end

  def response(id, t)
    @requests.delete(id) << Response.new(t)
  end
end

test_client = TestClient.new
test_wait = TestWaiterActor.new(test_client)
test_condition = TestConditionActor.new(test_client)
test_observer = TestObserverActor.new(test_client)
test_future = TestFutureActor.new(test_client)

COUNT = getenv('COUNT', 1000) { |v| Integer(v) }

benchmark(
  'wait'      => -> {
    map_futures(1..COUNT) {|id| sleep 0.001; test_wait.future.request(id) }
  },
  'condition' => -> {
    map_futures(1..COUNT) {|id| sleep 0.001; test_condition.future.request(id) }
  },
  'observer'  => -> {
    map_futures(1..COUNT) {|id| sleep 0.001; test_observer.future.request(id) }
  },
  'future'    => -> {
    map_futures(1..COUNT) {|id| sleep 0.001; test_future.future.request(id) }
  },
)
