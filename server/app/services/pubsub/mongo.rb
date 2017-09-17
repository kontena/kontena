require_relative 'base'

module Pubsub
  class Mongo < Base

    attr_accessor :collection

    # @param [Mongoid::Document] model
    def initialize(model)
      # The collection session is local to this Actor's thread
      @collection = model.collection
      @subscriptions = []
      async.stream!
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

    # @param [Mongoid::Document] model
    def self.start!(model)
      @supervisor = Celluloid.supervise(as: :pubsub, type: self, args: [model])
    end

    private

    def stream!
      actor = self.current_actor
      ensure_collection!
      defer {
        begin
          latest = self.collection.find.sort(:$natural => -1).limit(1).first
          query = {_id: {:$gt => latest[:_id]}}
          info "starting to tail collection"
          self.collection.find(query, {cursor_type: :tailable_await, batch_size: 100}).sort(:$natural => 1).each do |item|
            channel = item['channel']
            data = MessagePack.unpack(item['data'].data)
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
end