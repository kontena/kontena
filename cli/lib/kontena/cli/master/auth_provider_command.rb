require_relative 'auth_provider/show_command'
require_relative 'auth_provider/config_command'

class Kontena::Cli::Master::AuthProviderCommand < Clamp::Command

  subcommand "show", "Display master authentication provider configuration", Kontena::Cli::Master::AuthProvider::ShowCommand
  subcommand "config", "Set master authentication provider configuration", Kontena::Cli::Master::AuthProvider::ConfigCommand

end

