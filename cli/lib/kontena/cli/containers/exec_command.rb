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
      queue = Queue.new
      stdin_reader = nil
      url = ws_url("#{current_grid}/#{container_id}", interactive: interactive?, shell: shell?, tty: tty?)
      ws = connect(url, token)
      ws.on :message do |msg|
        data = parse_message(msg)
        queue << data if data.is_a?(Hash)
      end
      ws.on :open do
        ws.text(cmd)
        stdin_reader = self.stream_stdin_to_ws(ws, tty: self.tty?) if self.interactive?
      end
      ws.on :close do |e|
        if e.reason.include?('code: 404')
          queue << {'exit' => 1, 'message' => 'Not found'}
        else
          queue << {'exit' => 1}
        end
      end
      ws.connect
      while msg = queue.pop
        self.handle_message(msg)
      end
    rescue SystemExit
      stdin_reader.kill if stdin_reader
      raise
    end
  end
end
