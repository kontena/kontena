require 'msgpack'
require_relative '../logging'

module Kontena::Workers
  class QueueWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    finalizer :at_exit

    attr_reader :queue, :client

    # @param [Kontena::WebsocketClient] client
    # @param [Queue] queue
    def initialize(client, queue)
      @client = client
      @queue = queue
      @process_state = :stopped
      @watch_state = :stopped

      info 'initialized'
      subscribe('websocket:connected', :on_websocket_connected)
      subscribe('websocket:disconnect', :on_websocket_disconnected)
      if client.connected?
        async.register_client_events
      end
    end

    def processing?
      @process_state == :running
    end

    def watching?
      @watch_state == :running
    end

    # @param [String] topic
    # @param [Hash] data
    def on_websocket_connected(topic, data)
      async.start_queue_processing
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    # @param [String] topic
    # @param [Hash] data
    def on_websocket_disconnected(topic, data)
      async.stop_queue_processing if processing?
    end

    def push(msg)
      @queue << msg
    end

    def start_queue_processing
      return if processing?

      info 'started to process msg queue'
      @process_state = :running
      stop_overflow_watcher
      publish('queue_worker:start', {})

      defer {
        while processing? && data = @queue.pop
          if data.is_a?(Hash)
            send_message(data)
            sleep 0.001
          end
        end
      }
    end

    # @param [Hash] item
    def send_message(item)
      client.send_message(MessagePack.dump(item).bytes)
    rescue => exc
      logger.error exc.message
    end

    def stop_queue_processing
      @process_state = :stopped
      @queue << :stop
      info 'stopped processing of msg queue'
      publish('queue_worker:stop', {})
      start_overflow_watcher
    end

    def start_overflow_watcher
      return if watching?

      @watch_state == :running
      while watching?
        cleanup_queue
        sleep 1
      end
    end

    def stop_overflow_watcher
      @watch_state = :stopped
    end

    def cleanup_queue
      if @queue.length > 10_000
        info 'queue is over limit, cleaning up'
        1000.times { @queue.pop }
      end
    end

    def at_exit
      @process_state = :stopped
      @queue << :stop
    end
  end
end
