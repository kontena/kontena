require 'nats/io/client'
require_relative 'base'

module Pubsub
  class Nats < Base

    CHANNEL = 'master_pubsub'.freeze

    # @param servers [Array<String>]
    def initialize(servers)
      @servers = servers
      @subscriptions = []
      @nats = NATS::IO::Client.new
      @nats.on_error do |e|
        error(e)
      end
      @nats.on_reconnect do
        info "reconnected to server at #{@nats.connected_server}"
      end
      @nats.on_close do
        warning "connection to NATS closed"
      end
      async.stream!
    end

    # @param channel [String]
    # @param data [Hash]
    def publish(channel, data)
      msg = { channel: channel, data: data }
      @nats.publish(CHANNEL, MessagePack.pack(msg))
    end

    # @param servers [Array<String>]
    def self.start!(servers)
      @supervisor = Celluloid.supervise(as: :pubsub, type: self, args: [servers])
    end

    private

    def stream!
      actor = self.current_actor
      @nats.connect(servers: @servers)
      @nats.subscribe(CHANNEL) do |msg|
        item = MessagePack.unpack(msg)
        actor.async.queue_message(item['channel'], item['data'])
      end
    end
  end
end