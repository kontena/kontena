module Kontena::Cli::Helpers
  module ExecHelper

    # @param [WebSocket::Client::Simple] ws 
    # @return [Thread]
    def stream_stdin_to_ws(ws)
      Thread.new {
        STDIN.raw {
          while char = STDIN.readpartial(1024)
            ws.send(JSON.dump({ stdin: char }))
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
        elsif data.has_key?('stream')
          if data['stream'] == 'stdout'
            $stdout << data['chunk'] 
          else 
            $stderr << data['chunk']
          end
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

    # @param [String] container_id
    # @return [String]
    def ws_url(container_id)
      url = require_current_master.url
      url << '/' unless url.end_with?('/')
      "#{url.sub('http', 'ws')}v1/containers/#{container_id}/exec"
    end

    # @param [String] url
    # @param [String] token
    # @return [WebSocket::Client::Simple]
    def connect(url, token)
      WebSocket::Client::Simple.connect(url, {
        headers: {
          'Authorization' => "Bearer #{token.access_token}",
          'Accept' => 'application/json'
        }
      })
    end
  end
end