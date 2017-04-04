require 'socket'
require 'uri'

module Kontena
  class LocalhostWebServer
    # Serves one request to http://localhost:<random_port>/cb
    #
    # Used for local webserver browser authentication flow.
    #
    # @example
    #   server = LocalhostWebServer.new
    #   server.url
    #    => "http://localhost:1234/cb"
    #   response = server.serve_one
    #   # <visit server.url?foo=bar&bar=123 on browser>
    #    => { "foo" => "bar", "bar" => 123 }  # (it converts integers!)
    attr_accessor :server, :success_response, :error_response, :port

    DEFAULT_ERROR_MESSAGE   = "Bad request"
    SUCCESS_URL             = "https://cloud.kontena.io/terminal-success"

    # Get new server instance
    #
    # @param [String] success_response Returned for successful callback
    # @param [String] error_response Returned for unsuccessful callback
    def initialize(success_response: nil, error_response: nil, port: nil)
      @success_response = success_response
      @error_response   = error_response   || DEFAULT_ERROR_MESSAGE
      @server = TCPServer.new('localhost', port || 0)
      @port = @server.addr[1]
    end

    # The url to this service, send this as redirect_uri to auth provider.
    def url
      "http://localhost:#{port}/cb"
    end

    # Serve one request and return query params.
    #
    # @return [Hash] query_params
    def serve_one
      ENV["DEBUG"] && $stderr.puts("Waiting for connection on port #{port}..")
      socket = server.accept

      content = socket.recvfrom(2048).first.split(/(?:\r)?\n/)

      request = content.shift

      headers = {}
      while line = content.shift
        break if line.nil?
        break if line == ''
        header, value = line.chomp.split(/:\s{0,}/, 2)
        headers[header] = value
      end

      body = content.join("\n")

      ENV["DEBUG"] && $stderr.puts("Got request: \"#{request.inspect}\n  Headers: #{headers.inspect}\n  Body: #{body}\"")

      get_request = request[/GET (\/cb.+?) HTTP/, 1]
      if get_request
        if success_response
          socket.print [
            'HTTP/1.1 200 OK',
            'Content-Type: text/html',
            "Content-Length: #{success_response.bytesize}",
            "Connection: close",
            '',
            success_response
          ].join("\r\n")
        else
          socket.print [
            'HTTP/1.1 302 Found',
            "Location: #{SUCCESS_URL}",
            "Referrer-Policy: no-referrer",
            "Connection: close",
            ''
          ].join("\r\n")
        end

        socket.close
        server.close
        uri = URI.parse("http://localhost#{get_request}")
        ENV["DEBUG"] && $stderr.puts("  * Parsing params: \"#{uri.query}\"")
        params = {}
        URI.decode_www_form(uri.query).each do |key, value|
          if value.to_s == ''
            next
          elsif value.to_s =~ /\A\d+\z/
            params[key] = value.to_i
          else
            params[key] = value
          end
        end
        params
      else
        # Unless it's a query to /cb, send an error message and keep listening,
        # it might have been something funny like fetching favicon.ico
        socket.print [
          'HTTP/1.1 400 Bad request',
          'Content-Type: text/plain',
          "Content-Length: #{error_response.bytesize}",
          'Connection: close',
          '',
          error_response
        ].join("\r\n")
        socket.close
        serve_one # serve more, this one was not proper.
      end
    end
  end
end
