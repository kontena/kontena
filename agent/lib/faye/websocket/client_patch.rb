require 'faye/websocket'

class Faye::WebSocket::Client
  module Connection
    def unbind(error = nil)
      parent.__send__(:emit_error, error) if error
      parent.__send__(:finalize_close)
    end
  end
end
