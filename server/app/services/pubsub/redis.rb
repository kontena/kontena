require 'redis'
require_relative 'base'

module Pubsub
  class Redis < Base

    CHANNEL = 'master_pubsub'.freeze

    # @param url [String]
    def initialize(url)
      @url = url
      @subscriptions = []
      async.stream!
    end

    # @param channel [String]
    # @param data [Hash]
    def publish(channel, data)
      msg = { channel: channel, data: data }
      redis.publish(CHANNEL, MessagePack.pack(msg))
    end

    # @param url [String]
    def self.start!(url)
      @supervisor = Celluloid.supervise(as: :pubsub, type: self, args: [url])
    end

    # @return [Redis]
    def redis
      @redis ||= ::Redis.new(url: @url)
    end

    private

    def stream!
      actor = self.current_actor
      defer {
        begin
          redis = ::Redis.new(url: @url)
          redis.subscribe(CHANNEL) do |on|
            on.message do |_, msg|
              item = MessagePack.unpack(msg)
              actor.async.queue_message(item['channel'], item['data'])
            end
          end
        rescue => exc
          error "error while tailing: #{exc.message}"
          error exc.backtrace
          sleep 0.1
          retry
        end
      }
    end
  end
end