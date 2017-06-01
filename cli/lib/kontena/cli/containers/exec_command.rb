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
      require_api_url
      token = require_token
      cmd = JSON.dump({cmd: cmd_list})
      url = ws_url("#{current_grid}/#{container_id}")
      url << 'interactive=true&' if interactive?
      url << 'shell=true' if shell?
      ws = connect(url, token)

      ws.on :message do |msg|
        self.handle_message(msg)
      end
      ws.on :open do
        ws.text(cmd)
      end
      ws.on :close do |e|
        exit 1
      end
      ws.connect
      if interactive?
        stream_stdin_to_ws(ws).join
      else 
        sleep
      end
    end
  end
end
