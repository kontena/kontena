require_relative '../../websocket/client'

module Kontena::Cli::Helpers
  module ExecHelper

    # @param [WebSocket::Client::Simple] ws 
    # @return [Thread]
    def stream_stdin_to_ws(ws)
      require 'io/console'
      Thread.new {
        if STDIN.tty?
          STDIN.raw {
            while char = STDIN.readpartial(1024)
              ws.text(JSON.dump({ stdin: char }))
            end
          }
        else
          while char = STDIN.gets
            ws.text(JSON.dump({ stdin: char }))
          end
          ws.text(JSON.dump({ stdin: nil }))
        end
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
      "#{url.sub('http', 'ws')}v1/containers/#{container_id}/exec?"
    end

    # @param [String] url
    # @param [String] token
    # @return [WebSocket::Client::Simple]
    def connect(url, token)
      options = {
        headers: {
          'Authorization' => "Bearer #{token.access_token}"
        }
      }
      if ENV['SSL_IGNORE_ERRORS'].to_s == 'true'
        options[:verify_mode] = ::OpenSSL::SSL::VERIFY_NONE
      end
      Kontena::Websocket::Client.new(url, options)
    end
  end
end