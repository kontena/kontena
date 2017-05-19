require_relative 'logging'

class MongoPubsub
  include Celluloid
  include Logging

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
      MongoPubsub.unsubscribe(self)
    end

    def stop
      @stopped = true
    end

    def stopped?
      @stopped == true
    end

    def queue_message(data)
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
      payload = Marshal::load(data.data)
      if payload.is_a?(Hash)
        # Serialization preserves symbol keys opposed to old un-serialized hash storing which automatically converted
        # symbol keys into strings.
        # There's lot of code paths where stringified keys are expected
        payload = payload.stringify_keys
      end
      
      @block.call(payload)
    end
  end

  attr_accessor :collection, :subscriptions

  # @param [Mongoid::Document] model
  def initialize(model)
    # The collection session is local to this Actor's thread
    @collection = model.collection
    @subscriptions = []
    async.tail!
  end

  # @param [String] channel
  # @return [Subscription]
  def subscribe(channel, block)
    subscription = Subscription.new(channel, block)
    self.subscriptions << subscription

    subscription
  end

  # @param [Subscription] subscription
  def unsubscribe(subscription)
    subscription.stop unless subscription.stopped?
    self.subscriptions.delete(subscription)
  end

  # @param [String] channel
  # @param [Hash] data
  def publish(channel, data)
    self.collection.insert_one(
      channel: channel,
      data: BSON::Binary.new(Marshal::dump(data)),
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
    actor = @supervisor.actors.first
    actor.subscriptions.each do |subscription|
      actor.unsubscribe(subscription)
    end
    actor.subscriptions = []
  end

  def self.subscriptions
    @supervisor.actors.first.subscriptions
  end

  private

  def tail!
    ensure_collection!
    defer {
      begin
        latest = self.collection.find.sort(:$natural => -1).limit(1).first
        query = {_id: {:$gt => latest[:_id]}}
        info "starting to tail collection"
        self.collection.find(query, {cursor_type: :tailable_await, batch_size: 100}).sort(:$natural => 1).each do |item|
          channel = item['channel']
          data = item['data']
          
          subscribers = self.subscriptions.select{|s| s.channel == channel }
          subscribers.each do |subscription|
            begin
              subscription.queue_message(data.dup) if subscription
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
