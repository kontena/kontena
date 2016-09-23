require_relative 'containers/exec_command'
require_relative 'containers/inspect_command'

class Kontena::Cli::ContainerCommand < Kontena::Command

  subcommand "exec", "Execute command inside a container", Kontena::Cli::Containers::ExecCommand
  subcommand "inspect", "Inspect the container", Kontena::Cli::Containers::InspectCommand

  def execute
  end
end
