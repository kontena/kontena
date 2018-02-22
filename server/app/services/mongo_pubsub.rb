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
      @future = Celluloid::Future.new do
        process
      end
    end

    def terminate
      stop
    end

    # Suspend the calling celluloid task until the subscription is stopped and finishes processing
    def wait
      @future.value
    end

    def stop
      @queue.close
    end

    # @param data [BSON::Binary] MessagePack'd data
    def queue_message(data)
      @queue << data
    rescue ClosedQueueError
      debug "dropped #{@channel}: closed"
    else
      debug "queued #{@channel}..."
    end

    private

    # runs the @future thread
    # returns once stopped, and queued messages have been processed
    def process
      while data = @queue.shift
        send_message(data)
      end
    end

    # @param data [BSON::Binary] MessagePack'd data
    def send_message(data)
      payload = HashWithIndifferentAccess.new(MessagePack.unpack(data.data))
      @block.call(payload)
    rescue => exc
      error exc
    end
  end

  attr_accessor :collection

  finalizer :finalize

  # @return [Array<Subscription>]
  def self.subscriptions
    @subscriptions ||= []
  end

  # @param [Mongoid::Document] model
  def initialize(model)
    # The collection session is local to this Actor's thread
    @collection = model.collection

    info "initialized"

    start
  end

  # @return [Array<Subscription>]
  def subscriptions
    self.class.subscriptions
  end

  def start
    async.tail!

    # restore any active subscriptions from before crash
    subscriptions.each do |subscription|
      debug "restoring #{subscription.channel}..."

      async.process_subscription(subscription)
    end
  end

  # @param [Subscription] subscription
  def process_subscription(subscription)
    subscription.wait
  rescue Celluloid::TaskTerminated # actor crashed
    debug "preserving #{subscription.channel} on crash"
    subscription = nil
  ensure
    if subscription
      debug "stopped #{subscription.channel}"
      subscriptions.delete(subscription)
    end
  end

  # @param [String] channel
  # @return [Subscription]
  def subscribe(channel, block)
    debug "subscribe #{channel}"

    subscription = Subscription.new(channel, block)
    subscriptions << subscription

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
    debug "publish #{channel}"

    self.collection.insert_one(
      channel: channel,
      data: BSON::Binary.new(MessagePack.pack(data)),
      created_at: Time.now.utc
    )
  end

  # @param channel [String]
  # @param data [BSON::Binary] MessagePack'd data
  def queue_message(channel, data)
    subscriptions.each do |subscription|
      subscription.queue_message(data.dup) if subscription.channel == channel
    end
  end

  # Stop all subscribers
  def clear!
    subscriptions.each do |subscription|
      subscription.stop
    end
    subscriptions.clear
  end

  def finalize
    info "terminated"
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

  def self.actor
    @supervisor.actors.first
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
