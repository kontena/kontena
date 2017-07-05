# WebSocket::Driver.client(...) API
class Kontena::Websocket::Client::Connection
  attr_reader :uri

  # @param uri [URI]
  # @param socket [TCPSocket, OpenSSL::SSL::SSLSocket]
  def initialize(uri, socket)
    @uri = uri
    @socket = socket
  end

  # @return [String]
  def url
    @uri.to_s
  end

  # @param buf [String]
  def write(buf)
    @socket.write(buf) # XXX: return/raise?
  end
end
