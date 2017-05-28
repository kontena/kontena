require_relative '../helpers/exec_helper'

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

      stream_stdin_to_ws(ws).join
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
