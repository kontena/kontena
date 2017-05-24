class Kontena::Cli::PluginCommand < Kontena::Command
  subcommand ["list","ls"], "List plugins", load_subcommand('plugins/list_command')
  subcommand "search", "Search plugins", load_subcommand('plugins/search_command')
  subcommand "install", "Install a plugin", load_subcommand('plugins/install_command')
  subcommand "uninstall", "Uninstall a plugin", load_subcommand('plugins/uninstall_command')
end
