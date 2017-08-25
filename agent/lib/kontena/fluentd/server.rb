require_relative 'server_connection'
require_relative 'message_processor'

module Kontena
  module Fluentd
    class Server
      include Celluloid
      include Kontena::Logging

      finalizer :finalize

      def initialize(autostart = true)
        info 'initialized'
        @connections = []
        @queue = SizedQueue.new(1000)
        @message_processor = Kontena::Fluentd::MessageProcessor.new(@queue)
        async.start if autostart
      end

      def start
        defer { run }
      end

      def run
        @running = true
        @server = TCPServer.new(24224)
        while @running do
          @connections << Kontena::Fluentd::ServerConnection.new(@server.accept, @queue)
        end
      rescue Errno::EACCES => exc
        error exc.message
      ensure
        @connections.each { |c| c.terminate if c.alive? }
        @server.close
      end

      def finalize
        @connections.each { |c| c.terminate if c.alive? }
        @message_processor.terminate
        @running = false
      end
    end
  end
end