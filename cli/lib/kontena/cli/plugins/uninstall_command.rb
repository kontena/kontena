require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME ...', 'Plugin name', attribute_name: :plugins

    def execute
      plugins.each do |name|
        exit_with_error "Plugin #{name} has not been installed" unless plugin_installed?(name)
        spinner "Uninstalling plugin #{pastel.cyan(name)}" do
          plugin_uninstaller(name).uninstall
        end
      end
    end

    # @param name [String]
    # @return [Boolean]
    def plugin_installed?(name)
      Kontena::PluginManager::Common.installed?(name)
    end

    # @param name [String]
    # @return [Kontena::PluginManager::Uninstaller]
    def plugin_uninstaller(name)
      Kontena::PluginManager::Uninstaller.new(name)
    end
  end
end
