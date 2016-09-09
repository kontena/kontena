require_relative 'containers/exec_command'
require_relative 'containers/inspect_command'
require_relative 'containers/logs_command'

class Kontena::Cli::ContainerCommand < Clamp::Command

  subcommand "exec", "Execute command inside a container", Kontena::Cli::Containers::ExecCommand
  subcommand "inspect", "Inspect the container", Kontena::Cli::Containers::InspectCommand
  subcommand "logs", "Show container logs", Kontena::Cli::Containers::LogsCommand

  def execute
  end
end
