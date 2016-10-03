require_relative 'grids/list_command'
require_relative 'grids/create_command'
require_relative 'grids/update_command'
require_relative 'grids/use_command'
require_relative 'grids/show_command'
require_relative 'grids/logs_command'
require_relative 'grids/remove_command'
require_relative 'grids/current_command'
require_relative 'grids/env_command'
require_relative 'grids/audit_log_command'
require_relative 'grids/user_command'
require_relative 'grids/cloud_config_command'
require_relative 'grids/trusted_subnet_command'

class Kontena::Cli::GridCommand < Kontena::Command

  subcommand ["list","ls"], "List all grids", Kontena::Cli::Grids::ListCommand
  subcommand "create", "Create a new grid", Kontena::Cli::Grids::CreateCommand
  subcommand "update", "Update grid", Kontena::Cli::Grids::UpdateCommand
  subcommand "use", "Switch to use specific grid", Kontena::Cli::Grids::UseCommand
  subcommand "show", "Show grid details", Kontena::Cli::Grids::ShowCommand
  subcommand "logs", "Show logs from grid containers", Kontena::Cli::Grids::LogsCommand
  subcommand ["remove","rm"], "Remove a grid", Kontena::Cli::Grids::RemoveCommand
  subcommand "current", "Show current grid details", Kontena::Cli::Grids::CurrentCommand
  subcommand "env", "Show the current grid environment details", Kontena::Cli::Grids::EnvCommand
  subcommand "audit-log", "Show audit log of the current grid", Kontena::Cli::Grids::AuditLogCommand
  subcommand "user", "User specific commands", Kontena::Cli::Grids::UserCommand
  subcommand "cloud-config", "Generate cloud-config", Kontena::Cli::Grids::CloudConfigCommand
  subcommand "trusted-subnet", "Trusted subnet related commands", Kontena::Cli::Grids::TrustedSubnetCommand

  def execute
  end
end
