require_relative '../helpers/rpc_helper'

module Kontena
  module Fluentd
    class ServerConnection
      include Celluloid
      include Kontena::Logging

      finalizer :close

      def initialize(connection, queue)
        @peeraddr = connection.peeraddr
        info "connection opened from #{@peeraddr[1]}:#{@peeraddr[2]}"
        @connection = connection
        @queue = queue
        async.receive
      end

      def receive
        unpacker = MessagePack::Unpacker.new(@connection)
        unpacker.each do |data|
          @queue << data
        end

        terminate
      end

      def close
        info "connection closed from #{@peeraddr[1]}:#{@peeraddr[2]}"
        @connection.close
      end
    end
  end
end