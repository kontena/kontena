require_relative '../helpers/exec_helper'

module Kontena::Cli::Containers
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::ExecHelper

    parameter "CONTAINER_ID", "Container id"
    parameter "CMD ...", "Command"

    option ["--shell"], :flag, "Execute as a shell command"
    option ["--interactive"], :flag, "Keep stdin open"

    def execute
      require 'websocket-client-simple'

      require_api_url
      token = require_token
      cmd = JSON.dump(cmd_list)
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

      if interactive?
        stream_stdin_to_ws(ws).join
      else 
        sleep
      end
    end

    # @param [String] token
    # @return [WebSocket::Client::Simple]
    def connect(token)
      url = "#{require_current_master.url.sub('http', 'ws')}/v1/containers/#{current_grid}/#{container_id}/exec?"
      url << 'interactive=true&' if interactive?
      url << 'shell=true&' if shell?
      WebSocket::Client::Simple.connect(url, {
        headers: {
          'Authorization' => "Bearer #{token.access_token}",
          'Accept' => 'application/json'
        }
      })
    end
  end
end
