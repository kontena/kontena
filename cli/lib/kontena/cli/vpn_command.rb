class Kontena::Cli::VpnCommand < Kontena::Command
  subcommand "create", "Create VPN service", load_subcommand('vpn/create_command')
  subcommand "config", "Show/Export VPN config", load_subcommand('vpn/config_command')
  subcommand ["remove", "rm"], "Remove VPN service", load_subcommand('vpn/remove_command')
end
