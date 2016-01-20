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
      Pubsub.subscribe('queue_worker:add_message') do |msg|
        self.queue << msg
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

      stop_overflow_watcher

      @queue_thread = Thread.new {
        info 'started processing'
        loop do
          begin
            item = @queue.pop
            client.send_message(MessagePack.dump(item).bytes)
            sleep 0.001
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

      start_overflow_watcher
    end

    def start_overflow_watcher
      return unless @overflow_thread.nil?

      @overflow_thread = Thread.new {
        info 'started overflow watcher'
        loop do
          begin
            cleanup_queue
            sleep 1
          rescue => exc
            logger.error exc.message
          end
        end
      }
    end

    def stop_overflow_watcher
      if @overflow_thread
        info 'stopped overflow watcher'
        @overflow_thread.kill
        @overflow_thread.join
        @overflow_thread = nil
      end
    end

    def cleanup_queue
      if @queue.length > 10_000
        info 'queue is over limit, cleaning up'
        1000.times { @queue.pop }
      end
    end
  end
end
