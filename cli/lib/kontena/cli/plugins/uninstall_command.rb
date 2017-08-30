require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::PluginManager::Common

    parameter 'NAME', 'Plugin name'

    def uninstaller
      Kontena::PluginManager::Uninstaller.new(name)
    end

    def execute
      exit_with_error "Plugin #{name} has not been installed" unless installed?(name)
      spinner "Uninstalling plugin #{pastel.cyan(name)}" do
        uninstaller.uninstall
      end
    end
  end
end