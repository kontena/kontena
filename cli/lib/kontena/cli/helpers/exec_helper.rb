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
      data = parse_message(msg)
      if data.is_a?(Hash)
        if data.has_key?('exit')
          exit data['exit'].to_i
        else
          $stdout << data['chunk']
        end
      end
    rescue => exc
      $stderr << "#{exc.class.name}: #{exc.message}"
    end

    # @param [Websocket::Frame::Incoming] msg
    def parse_message(msg)
      JSON.parse(msg.data)
    rescue JSON::ParserError
      nil
    end
  end
end