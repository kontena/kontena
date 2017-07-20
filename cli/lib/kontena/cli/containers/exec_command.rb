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

    requires_current_master
    requires_current_grid

    def execute
      Kontena::Websocket::Logging.initialize_logger(STDERR, Logger::WARN)

      exit_status = container_exec(current_grid, self.container_id, self.cmd_list, interactive: interactive?, shell: shell?, tty: tty?)

      exit exit_status unless exit_status.zero?
    end
  end
end
