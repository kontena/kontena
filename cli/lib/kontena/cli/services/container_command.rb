
class Kontena::Cli::ContainerCommand < Kontena::Command

  subcommand "exec", "Execute command inside a container", load_subcommand('containers/exec_command')

  def execute
  end
end