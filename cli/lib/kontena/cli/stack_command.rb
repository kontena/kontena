class Kontena::Cli::StackCommand < Kontena::Command
  subcommand "install", "Install a stack to a grid", load_subcommand('stacks/install_command')
  subcommand ["ls", "list"], "List installed stacks in a grid", load_subcommand('stacks/list_command')
  subcommand ["remove","rm"], "Remove a deployed stack from a grid", load_subcommand('stacks/remove_command')
  subcommand "show", "Show details about a stack in a grid", load_subcommand('stacks/show_command')
  subcommand "upgrade", "Upgrade a stack in a grid", load_subcommand('stacks/upgrade_command')
  subcommand ["start", "deploy"], "Deploy an installed stack in a grid", load_subcommand('stacks/deploy_command')
  subcommand "logs", "Show logs from services in a stack", load_subcommand('stacks/logs_command')
  subcommand "events", "Show events from services in a stack", load_subcommand('stacks/events_command')
  subcommand "monitor", "Monitor services in a stack", load_subcommand('stacks/monitor_command')
  subcommand "build", "Build images listed in a stack file and push them to an image registry", load_subcommand('stacks/build_command')
  subcommand ["reg", "registry"], "Stack registry related commands", load_subcommand('stacks/registry_command')
  subcommand "validate", "Process and validate a stack file", load_subcommand('stacks/validate_command')

  def execute
  end
end
