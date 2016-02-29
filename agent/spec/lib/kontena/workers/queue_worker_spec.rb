require_relative '../../../spec_helper'

describe Kontena::Workers::QueueWorker do

  class TestWsClient

    attr_accessor :events

    def initialize
      @events = {}
    end

    def on(event, &block)
      @events[event] = block
    end

    def trigger(event)
      if @events[event]
        @events[event].call
      end
    end

    def send(msg)
    end
  end

  class TestClient
    attr_accessor :ws
    delegate :on, to: :ws

    def initialize(ws)
      self.ws = ws
    end
  end

  def wait_empty_queue(queue)
    sleep 0.00001 while queue.length > 0
  end

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:queue) { Queue.new }
  let(:client) { TestClient.new(ws) }
  let(:subject) { described_class.new(client, queue) }
  let(:msg) { {hello: 'world'} }

  
end
