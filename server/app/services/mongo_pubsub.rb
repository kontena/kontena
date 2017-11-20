require_relative 'logging'

class MongoPubsub
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
      payload = HashWithIndifferentAccess.new(MessagePack.unpack(data.data))
      @block.call(payload)
    rescue => exc
      error exc
    end
  end

  attr_accessor :collection

  # @param [Mongoid::Document] model
  def initialize(model)
    # The collection session is local to this Actor's thread
    @collection = model.collection
    @subscriptions = []
    async.tail!
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
    self.collection.insert_one(
      channel: channel,
      data: BSON::Binary.new(MessagePack.pack(data)),
      created_at: Time.now.utc
    )
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

  # @param [Mongoid::Document] model
  def self.start!(model)
    @supervisor = Celluloid.supervise(as: :mongo_pubsub, type: MongoPubsub, args: [model])
  end

  def self.clear!
    @supervisor.actors.first.clear!
  end

  private

  def tail!
    actor = self.current_actor
    ensure_collection!
    defer {
      begin
        latest = self.collection.find.sort(:$natural => -1).limit(1).first
        query = {_id: {:$gt => latest[:_id]}}
        info "starting to tail collection"
        self.collection.find(query, {cursor_type: :tailable_await, batch_size: 100}).sort(:$natural => 1).each do |item|
          channel = item['channel']
          data = item['data']

          actor.async.queue_message(channel, data)
        end
      rescue => exc
        error "error while tailing: #{exc.message}"
        error exc.backtrace
        sleep 0.1
        retry
      end
    }
  end

  def ensure_collection!
    unless self.collection.client.database.collection_names.include?(self.collection.name)
      self.collection.client.command(create: self.collection.name)
    end
    unless self.collection.capped?
      self.collection.client.command(
        convertToCapped: self.collection.name,
        capped: true,
        size: 24.megabytes
      )
      self.publish('test', {})
    end
  end
end
