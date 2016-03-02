module Kontena
  class Pubsub

    class Subscription
      attr_reader :channel

      # @param [String] channel
      def initialize(channel, block)
        @channel = channel
        @block = block
        @queue = []
        @process = false
        @stopped = false
      end

      def processing?
        @process == true
      end

      def terminate
        stop
        Pubsub.unsubscribe(self)
      end

      def stop
        @stopped = true
      end

      def stopped?
        @stopped == true
      end

      def push(data)
        return if stopped?
        @queue << data
        unless processing?
          process
        end
      end

      private

      def process
        @process = true
        Celluloid::Future.new {
          while @process == true && @stopped == false
            data = @queue.shift
            if data
              send_message(data)
            else
              @process = false
            end
          end
        }
      end

      # @param [Hash] data
      def send_message(data)
        @block.call(data)
      end
    end

    # @return [Array<Subscription>]
    def self.subscriptions
      @subscriptions ||= []
    end

    # @param [String] channel
    # @return [Subscription]
    def self.subscribe(channel, &block)
      subscription = Subscription.new(channel, block)
      subscriptions << subscription

      subscription
    end

    # @param [Subscription]
    def self.unsubscribe(subscription)
      subscription.stop unless subscription.stopped?
      subscriptions.delete(subscription)
    end

    # @param [String] channel
    # @param [Object] msg
    def self.publish(channel, msg)
      Celluloid::Notifications.publish(channel, msg)
      receivers = subscriptions.select{|s| s.channel == channel}
      receivers.each do |subscription|
        begin
          subscription.push(msg)
        rescue
          unsubscribe(subscription)
        end
      end
    end

    def self.clear!
      while subscriptions.size > 0
        subscriptions.each do |sub|
          unsubscribe(sub)
        end
      end
    end
  end
end
