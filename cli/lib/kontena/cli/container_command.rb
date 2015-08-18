require_relative 'containers/exec_command'

class Kontena::Cli::ContainerCommand < Clamp::Command

  subcommand "exec", "Execute command inside a container", Kontena::Cli::Containers::ExecCommand

  def execute
  end
end
