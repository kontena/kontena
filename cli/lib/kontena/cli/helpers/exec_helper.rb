module Kontena::Cli::Helpers
  module ExecHelper

    # @param [WebSocket::Client::Simple] ws 
    # @return [Thread]
    def stream_stdin_to_ws(ws)
      Thread.new {
        STDIN.raw {
          while char = STDIN.readpartial(1024)
            ws.send(char)
          end
        }
      }
    end

    # @param [Websocket::Frame::Incoming] msg
    def handle_message(msg)
      data = JSON.parse(msg.data)
      if data
        if data['exit']
          exit data['exit'].to_i
        else
          $stdout << data['chunk']
        end
      end
    rescue JSON::ParserError
      # should we handle these?
    rescue => exc
      $stderr << exc.message
    end
  end
end