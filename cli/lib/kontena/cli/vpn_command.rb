require_relative 'vpn/create_command'
require_relative 'vpn/config_command'
require_relative 'vpn/delete_command'

class Kontena::Cli::VpnCommand < Clamp::Command

  subcommand "create", "Create VPN service", Kontena::Cli::Vpn::CreateCommand
  subcommand "config", "Show/Export VPN config", Kontena::Cli::Vpn::ConfigCommand
  subcommand "delete", "Delete VPN service", Kontena::Cli::Vpn::DeleteCommand

  def execute
  end
end
