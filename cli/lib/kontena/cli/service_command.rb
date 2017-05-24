class Kontena::Cli::ServiceCommand < Kontena::Command
  subcommand ["list","ls"], "List services", load_subcommand('services/list_command')
  subcommand "create", "Create a new service", load_subcommand('services/create_command')
  subcommand "show", "Show service details", load_subcommand('services/show_command')
  subcommand "update", "Update service configuration", load_subcommand('services/update_command')
  subcommand "deploy", "Deploy service", load_subcommand('services/deploy_command')
  subcommand "stop", "Stop service", load_subcommand('services/stop_command')
  subcommand "start", "Start service", load_subcommand('services/start_command')
  subcommand "restart", "Restart service", load_subcommand('services/restart_command')
  subcommand "scale", "Scale service", load_subcommand('services/scale_command')
  subcommand ["remove", "rm"], "Remove service", load_subcommand('services/remove_command')
  subcommand "containers", "List service containers", load_subcommand('services/containers_command')
  subcommand "logs", "Show service logs", load_subcommand('services/logs_command')
  subcommand "events", "Show service events", load_subcommand('services/events_command')
  subcommand "stats", "Show service statistics", load_subcommand('services/stats_command')
  subcommand "monitor", "Monitor", load_subcommand('services/monitor_command')

  subcommand "env", "Environment variable specific commands", load_subcommand('services/env_command')

  subcommand "secret", "Secret specific commands", load_subcommand('services/secret_command')

  subcommand "link", "Link service to another service", load_subcommand('services/link_command')
  subcommand "unlink", "Unlink service from another service", load_subcommand('services/unlink_command')
  subcommand "exec", "Execute commands in service containers", load_subcommand('services/exec_command')

  def execute
  end
end
