require 'forwardable'
require 'socket'
require 'openssl'

module Kontena
  module Websocket
    module Client
      class Connection
        extend Forwardable

        FRAME_SIZE = 1024

        attr_reader :url

        # @param [String] url
        # @param [Hash] options
        def initialize(url, options = {})
          @options = options
          @url = url
          @client = ::WebSocket::Driver.client(self)
          if headers = options[:headers]
            headers.each do |k, v|
              @client.set_header(k, v)
            end
          end
        end

        def connect
          uri = URI.parse(@url)
          port = uri.port || (uri.scheme == "ws" ? 80 : 443)
          @socket = ::TCPSocket.new(uri.host, port)
          if uri.scheme == "wss"
            ctx = ::OpenSSL::SSL::SSLContext.new
            ctx.ssl_version = @options[:ssl_version] if @options[:ssl_version]
            ctx.verify_mode = @options[:verify_mode] if @options[:verify_mode]
            cert_store = ::OpenSSL::X509::Store.new
            cert_store.set_default_paths
            ctx.cert_store = cert_store
            @socket = ::OpenSSL::SSL::SSLSocket.new(@socket, ctx)
            @socket.connect
          end
          @client.start
          Thread.new { self.read_socket }
        end

        def_delegators :@client, :text, :binary, :ping, :close, :protocol, :on

        def write(buffer)
          @socket.write buffer
        end

        def read_socket
          loop do
            begin
              @client.parse(@socket.readpartial(FRAME_SIZE))
            rescue EOFError
              break
            end
          end
        end
      end
    end
  end
end

