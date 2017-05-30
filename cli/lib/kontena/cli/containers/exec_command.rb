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
      cmd = JSON.dump({cmd: cmd_list})
      base = self
      ws = connect(ws_url("#{current_grid}/#{container_id}"), token)
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
  end
end
