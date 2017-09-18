require_relative '../logging'

module Pubsub
  class Base
    include Celluloid
    include Logging

    class Subscription
      include Logging

      attr_reader :channel

      # @param [String] channel
      # @param [Proc] block
      def initialize(channel, block)
        @channel = channel
        @block = block
        @queue = Queue.new
      end

      def terminate
        stop
      end

      def stop
        @queue.close
      end

      def queue_message(data)
        @queue << data
      rescue ClosedQueueError
        nil
      end

      # returns once stopped, and queued messages have been processed
      def process
        while data = @queue.shift
          send_message(data)
        end
      end

      private

      # @param [Hash] data
      def send_message(data)
        payload = HashWithIndifferentAccess.new(data)
        @block.call(payload)
      rescue => exc
        error exc
      end
    end

    # @param [Subscription] subscription
    def process_subscription(subscription)
      defer {
        subscription.process
      }
    ensure
      @subscriptions.delete(subscription)
    end

    # @param [String] channel
    # @return [Subscription]
    def subscribe(channel, block)
      subscription = Subscription.new(channel, block)
      @subscriptions << subscription

      async.process_subscription(subscription)

      subscription
    end

    # @param [Subscription] subscription
    def unsubscribe(subscription)
      subscription.stop
    end

    # @param [String] channel
    # @param [Hash] data
    def publish(channel, data)
    end

    # @param [String] channel
    # @param [Hash] data
    def queue_message(channel, data)
      @subscriptions.each do |subscription|
        subscription.queue_message(data.dup) if subscription.channel == channel
      end
    end

    # Stop all subscribers
    def clear!
      @subscriptions.each do |subscription|
        subscription.stop
      end
      @subscriptions = []
    end

    # @param [String] channel
    # @param [Hash] data
    def self.publish(channel, data)
      @supervisor.actors.first.publish(channel, data)
    end

    # @param [String] channel
    # @param [Hash] data
    def self.publish_async(channel, data)
      @supervisor.actors.first.async.publish(channel, data)
    end

    # @param [String] channel
    # @return [Subscription]
    def self.subscribe(channel, &block)
      @supervisor.actors.first.subscribe(channel, block)
    end

    # @param [Subscription] subscription
    def self.unsubscribe(subscription)
      @supervisor.actors.first.unsubscribe(subscription)
    end

    def self.started?
      !@supervisor.nil?
    end

    def self.start!
      @supervisor = Celluloid.supervise(as: :pubsub, type: self)
    end

    def self.clear!
      @supervisor.actors.first.clear!
    end
  end
end