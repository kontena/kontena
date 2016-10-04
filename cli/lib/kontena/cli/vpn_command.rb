require_relative 'vpn/create_command'
require_relative 'vpn/config_command'
require_relative 'vpn/remove_command'
require_relative 'vpn/delete_command'

class Kontena::Cli::VpnCommand < Kontena::Command

  subcommand "create", "Create VPN service", Kontena::Cli::Vpn::CreateCommand
  subcommand "config", "Show/Export VPN config", Kontena::Cli::Vpn::ConfigCommand
  subcommand ["remove", "rm"], "Remove VPN service", Kontena::Cli::Vpn::RemoveCommand

  def execute
  end
end
