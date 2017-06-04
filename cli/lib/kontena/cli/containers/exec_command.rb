require_relative '../helpers/exec_helper'

module Kontena::Cli::Containers
  class ExecCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::ExecHelper

    parameter "CONTAINER_ID", "Container id"
    parameter "CMD ...", "Command"

    option ["--shell"], :flag, "Execute as a shell command"
    option ["-i", "--interactive"], :flag, "Keep stdin open"
    option ["-t", "--tty"], :flag, "Allocate a pseudo-TTY"

    def execute
      exit_with_error "the input device is not a TTY" if tty? && !STDIN.tty?

      require_api_url
      token = require_token
      cmd = JSON.dump({cmd: cmd_list})
      url = ws_url("#{current_grid}/#{container_id}")
      url << 'interactive=true&' if interactive?
      url << 'tty=true&' if tty?
      url << 'shell=true' if shell?
      ws = connect(url, token)

      ws.on :message do |msg|
        self.handle_message(msg)
      end
      ws.on :open do
        ws.text(cmd)
        self.stream_stdin_to_ws(ws) if interactive?
      end
      ws.on :close do |e|
        if e.reason.include?('code: 404')
          exit_with_error('Not found')
        else
          exit 1
        end
      end
      ws.connect
      sleep
    end
  end
end
