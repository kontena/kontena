
class Kontena::Cli::AppCommand < Kontena::Command

  warn Kontena.pastel.yellow("[DEPRECATED] The `kontena app` commands are deprecated in favor of `kontena stack` commands and will be removed in future releases")

  subcommand "init", "Init Kontena application", load_subcommand('apps/init_command')
  subcommand "build", "Build Kontena services", load_subcommand('apps/build_command')
  subcommand "config", "View service configurations", load_subcommand('apps/config_command')
  subcommand "deploy", "Deploy Kontena services", load_subcommand('apps/deploy_command')
  subcommand "scale", "Scale services", load_subcommand('apps/scale_command')
  subcommand "start", "Start services", load_subcommand('apps/start_command')
  subcommand "stop", "Stop services", load_subcommand('apps/stop_command')
  subcommand "restart", "Restart services", load_subcommand('apps/restart_command')
  subcommand "show", "Show service details", load_subcommand('apps/show_command')
  subcommand ["ps", "list", "ls"], "List services", load_subcommand('apps/list_command')
  subcommand ["logs"], "Show service logs", load_subcommand('apps/logs_command')
  subcommand "monitor", "Monitor services", load_subcommand('apps/monitor_command')
  subcommand ["remove","rm"], "Remove services", load_subcommand('apps/remove_command')

  def execute
  end
end