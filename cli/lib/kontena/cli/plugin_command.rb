require_relative 'plugins/list_command'

class Kontena::Cli::PluginCommand < Clamp::Command

  subcommand ["list","ls"], "List plugins", Kontena::Cli::Plugins::ListCommand

  def execute
  end
end
