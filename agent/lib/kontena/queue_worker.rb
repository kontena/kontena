require 'msgpack'
require_relative 'logging'

module Kontena
  class QueueWorker
    include Kontena::Logging

    attr_reader :queue, :client

    def initialize
      @queue = Queue.new
      Pubsub.subscribe('websocket:connect') do |client|
        self.client = client
      end
      Pubsub.subscribe('websocket:connected') do |event|
        self.register_client_events
      end
      info 'initialized'
    end

    ##
    # @param [WebsocketClient] client
    def client=(client)
      @client = client
    end

    def register_client_events
      self.start_queue_processing
      client.on :close do |event|
        self.stop_queue_processing
      end
    end

    ##
    # Start to process queue
    #
    def start_queue_processing
      return unless @queue_thread.nil?

      info 'started processing'
      @queue_thread = Thread.new {
        loop do
          begin
            item = @queue.pop
            client.send_message(MessagePack.dump(item).bytes)
          rescue => exc
            logger.error exc.message
          end
        end
      }
    end

    ##
    # Stop queue processing
    #
    def stop_queue_processing
      if @queue_thread
        info 'stopped processing'
        @queue_thread.kill
        @queue_thread.join
        @queue_thread = nil
      end
    end

    ##
    # @param [Hash] event
    def on_queue_push(event)
      if @queue.length > 10_000
        debug 'queue is over limit, popping item'
        @queue.pop
      end
      @queue << event
    end
  end
end
