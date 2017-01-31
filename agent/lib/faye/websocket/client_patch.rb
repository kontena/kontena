require 'faye/websocket'

class Faye::WebSocket::Client
  def emit_close(reason, code = 1006)
    @close_params = [reason, code]

    finalize_close
  end

  module Connection
    def unbind(reason = nil)
      if reason
        parent.__send__ :emit_close, reason
      else
        parent.__send__ :finalize_close
      end
    end
  end
end
