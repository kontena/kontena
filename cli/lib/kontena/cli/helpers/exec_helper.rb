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

    # @param [Hash] msg
    def handle_message(msg)
      if msg.has_key?('exit')
        if msg['message']
          exit_with_error(msg['message'])
        else
          exit msg['exit'].to_i
        end
      elsif msg.has_key?('stream')
        if msg['stream'] == 'stdout'
          $stdout << msg['chunk']
        else
          $stderr << msg['chunk']
        end
      end
    end

    # @param [Websocket::Frame::Incoming] msg
    def parse_message(msg)
      JSON.parse(msg.data)
    rescue JSON::ParserError
      nil
    end

    # @param container_id [String] The container id
    # @param interactive [Boolean] Interactive TTY on/off
    # @param shell [Boolean] Shell on/of
    # @param tty [Boolean] TTY on/of
    # @return [String]
    def ws_url(container_id, interactive: false, shell: false, tty: false)
      require 'uri' unless Object.const_defined?(:URI)
      extend Kontena::Cli::Common unless self.respond_to?(:require_current_master)

      url = URI.parse(require_current_master.url)
      url.scheme = url.scheme.sub('http', 'ws')
      url.path = "/v1/containers/#{container_id}/exec"
      if shell || interactive || tty
        query = {}
        query.merge!(interactive: true) if interactive
        query.merge!(shell: true) if shell
        query.merge!(tty: true) if tty
        url.query = URI.encode_www_form(query)
      end
      url.to_s
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
