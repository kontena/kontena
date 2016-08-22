require_relative 'plugins/list_command'
require_relative 'plugins/search_command'
require_relative 'plugins/install_command'
require_relative 'plugins/uninstall_command'

class Kontena::Cli::PluginCommand < Kontena::Command

  subcommand ["list","ls"], "List plugins", Kontena::Cli::Plugins::ListCommand
  subcommand "search", "Search plugins", Kontena::Cli::Plugins::SearchCommand
  subcommand "install", "Install a plugin", Kontena::Cli::Plugins::InstallCommand
  subcommand "uninstall", "Uninstall a plugin", Kontena::Cli::Plugins::UninstallCommand

  def execute
  end
end
