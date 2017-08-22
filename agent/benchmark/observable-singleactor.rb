#!/usr/bin/env ruby

require 'benchmark'
require_relative '../lib/kontena-agent'
require 'active_support/core_ext/enumerable'

Kontena::Logging.initialize_logger(STDERR, (ENV['LOG_LEVEL'] || Logger::WARN).to_i)

class TestClient
  include Celluloid
  include Kontena::Logging

  DELAY_MIN = 0.0
  DELAY_MAX = 1.0

  def send(id, actor)
    delay = DELAY_MIN + rand() * (DELAY_MAX - DELAY_MIN)

    #debug "request id=#{id} with delay=#{'%.2f' % delay}s"

    after(delay) {
      #debug "response id=#{id}..."

      actor.response(id, Time.now)
    }
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

N = 1000

Benchmark.bm(12) do |bm|
  test_client = TestClient.new
  test_observer = TestObserverActor.new(test_client)
  test_waiter = TestWaiterActor.new(test_client)

  stats = {}

  bm.report("wait") {
    futures = (1..N).map{|id| sleep 0.001; test_waiter.future.request(id) }

    total_delay = futures.map{|f| f.value }.sum

    stats[:wait] = {
      total_delay: total_delay
    }
  }
  bm.report("observer") {
    futures = (1..N).map{|id| sleep 0.001; test_observer.future.request(id) }

    total_delay = futures.map{|f| f.value }.sum

    stats[:observer] = {
      total_delay: total_delay
    }
  }

  puts "%-12s %12s" % ['', 'delay']
  stats.each_pair do |what, stat|
    puts '%-12s %12.6f' % [what, stat[:total_delay]]
  end
end
