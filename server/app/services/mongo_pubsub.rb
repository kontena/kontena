require_relative 'logging'

class MongoPubsub
  include Celluloid
  include Logging

  class Subscription
    include Celluloid

    finalizer :cleanup
    attr_reader :channel

    # @param [String] channel
    def initialize(channel, block)
      @channel = channel
      @block = block
      @queue = []
      async.process
    end

    def process
      sleep 0.001
      @process = true
      while @process == true
        data = @queue.shift
        send_message(data) if data
        sleep 0.001
      end
      @queue.clear
    end

    def queue_message(data)
      @queue << data
    end

    private

    # @param [Hash] data
    def send_message(data)
      @block.call(data)
    end

    def cleanup
      @process = false
    end
  end

  trap_exit :trap_subscription_exit
  attr_accessor :collection, :subscriptions

  # @param [Moped::Collection]
  def initialize(collection)
    @collection = collection
    @subscriptions = []
    async.tail!
  end

  # @param [String] channel
  # @return [Subscription]
  def subscribe(channel, block)
    subscription = Subscription.new(channel, block)
    self.link subscription
    self.subscriptions << subscription

    subscription
  end

  # @param [Subscription] subscription
  def unsubscribe(subscription)
    subscription.terminate if subscription.alive?
    self.subscriptions.delete(subscription)
  end

  # @param [String] channel
  # @param [Hash] data
  def publish(channel, data)
    self.collection.insert(
      channel: channel,
      data: data,
      created_at: Time.now.utc
    )
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

  def self.start!(collection)
    @supervisor = self.supervise(collection)
  end

  def self.clear!
    actor = @supervisor.actors.first
    actor.subscriptions.each do |subscription|
      actor.unsubscribe(subscription)
    end
    actor.subscriptions = []
  end

  private

  def tail!
    ensure_collection!
    defer {
      begin
        latest = self.collection.find.sort(:$natural => -1).limit(1).first
        query = {_id: {:$gt => latest[:_id]}}
        info "starting to tail collection"
        self.collection.find(query).sort(:$natural => 1).tailable.each do |item|
          channel = item['channel']
          data = item['data'].freeze
          subscribers = self.subscriptions.select{|s|
            begin
              s.alive? && s.channel == channel
            rescue Celluloid::DeadActorError
              false
            end
          }
          subscribers.each do |subscription|
            begin
              subscription.async.queue_message(data) if subscription && subscription.alive?
            rescue Celluloid::DeadActorError
            end
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

  def ensure_collection!
    unless self.collection.session.collection_names.include?(self.collection.name)
      self.collection.session.command(create: self.collection.name)
    end
    unless self.collection.capped?
      self.collection.session.command(
        convertToCapped: self.collection.name,
        capped: true,
        size: 24.megabytes
      )
      self.publish('test', {})
    end
  end

  def trap_subscription_exit(subscription, reason)
    self.unsubscribe(subscription)
  end
end
