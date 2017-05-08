module Kontena::Cli::Containers
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "CONTAINER_ID", "Container id"
    parameter "CMD ...", "Command"

    def execute
      require 'websocket-client-simple'
      require 'io/console'

      require_api_url
      token = require_token
      cmd = Shellwords.join(cmd_list)
      base = self
      ws = connect(token)
      ws.on :message do |msg|
        base.handle_message(msg)
      end
      ws.on :open do
        ws.send(cmd)
      end
      ws.on :close do |e|
        exit 1
      end
      stdin_thread = Thread.new {
        STDIN.raw {
          while char = STDIN.readpartial(1024)
            ws.send(char)
          end
        }
      }
      stdin_thread.join
    end

    # @param [Docker::Container] container
    def handle_message(msg)
      data = JSON.parse(msg.data)
      if data 
        if data['exit']
          exit data['exit'].to_i
        else 
          if data['stream'] == 'stderr'.freeze
            STDERR << data['chunk']
          else 
            STDOUT << data['chunk']
          end
        end
      end
    rescue => exc
      STDERR << exc.message
    end

    # @param [String] token
    # @return [WebSocket::Client::Simple]
    def connect(token)
      url = "#{require_current_master.url.sub('http', 'ws')}/v1/containers/#{current_grid}/#{container_id}/exec"
      WebSocket::Client::Simple.connect(url, {
        headers: {
          'Authorization' => "Bearer #{token.access_token}",
          'Accept' => 'application/json'
        }
      })
    end
  end
end
