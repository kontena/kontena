class Kontena::Cli::ContainerCommand < Kontena::Command
  subcommand ["list", "ls"], "List grid containers", load_subcommand('containers/list_command')
  subcommand "exec", "Execute command inside a container", load_subcommand('containers/exec_command')
  subcommand "inspect", "Inspect the container", load_subcommand('containers/inspect_command')
  subcommand "logs", "Show container logs", load_subcommand('containers/logs_command')
end
