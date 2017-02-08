require_relative 'containers/list_command'
require_relative 'containers/exec_command'
require_relative 'containers/inspect_command'
require_relative 'containers/logs_command'

class Kontena::Cli::ContainerCommand < Kontena::Command

  subcommand ["list", "ls"], "List grid containers", Kontena::Cli::Containers::ListCommand
  subcommand "exec", "Execute command inside a container", Kontena::Cli::Containers::ExecCommand
  subcommand "inspect", "Inspect the container", Kontena::Cli::Containers::InspectCommand
  subcommand "logs", "Show container logs", Kontena::Cli::Containers::LogsCommand

  def execute
  end
end
