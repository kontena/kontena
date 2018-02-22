class Kontena::Cli::GridCommand < Kontena::Command

  subcommand ["list","ls"], "List all grids", load_subcommand('grids/list_command')
  subcommand "create", "Create a new grid", load_subcommand('grids/create_command')
  subcommand "update", "Update grid", load_subcommand('grids/update_command')
  subcommand "use", "Switch to use specific grid", load_subcommand('grids/use_command')
  subcommand "show", "Show grid details", load_subcommand('grids/show_command')
  subcommand "logs", "Show logs from grid containers", load_subcommand('grids/logs_command')
  subcommand "events", "Show events from grid", load_subcommand('grids/events_command')
  subcommand ["remove","rm"], "Remove a grid", load_subcommand('grids/remove_command')
  subcommand "current", "Show current grid details", load_subcommand('grids/current_command')
  subcommand "env", "Show the current grid environment details", load_subcommand('grids/env_command')
  subcommand "audit-log", "Show audit log of the current grid", load_subcommand('grids/audit_log_command')
  subcommand "user", "User specific commands", load_subcommand('grids/user_command')
  subcommand "cloud-config", "Generate cloud-config", load_subcommand('grids/cloud_config_command')
  subcommand "trusted-subnet", "Trusted subnet related commands", load_subcommand('grids/trusted_subnet_command')
  subcommand "health", "Check grid health", load_subcommand('grids/health_command')

  def execute
  end
end
