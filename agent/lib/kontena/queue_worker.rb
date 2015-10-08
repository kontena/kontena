require 'msgpack'
require_relative 'logging'

module Kontena
  class QueueWorker
    include Kontena::Logging

    LOG_NAME = 'QueueWorker'

    attr_reader :queue, :client

    def initialize
      @queue = Queue.new
      logger.info(LOG_NAME) { 'initialized' }
      Pubsub.subscribe('websocket:connect') do |client|
        self.client = client
      end
      Pubsub.subscribe('websocket:connected') do |event|
        self.register_client_events
      end
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

      logger.info(LOG_NAME) { 'started processing' }
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
        logger.info(LOG_NAME) { 'stopped processing' }
        @queue_thread.kill
        @queue_thread.join
        @queue_thread = nil
      end
    end

    ##
    # @param [Hash] event
    def on_queue_push(event)
      logger.debug(LOG_NAME) { "queue push: #{event}" }
      if @queue.length > 1000
        logger.debug(LOG_NAME) { 'queue is over limit, popping item' }
        @queue.pop
      end
      @queue << event
    end
  end
end
