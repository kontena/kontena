require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::PluginManager::Common

    parameter 'NAME ...', 'Plugin name', attribute_name: :plugins

    def execute
      plugins.each do |name|
        exit_with_error "Plugin #{name} has not been installed" unless installed?(name)
        spinner "Uninstalling plugin #{pastel.cyan(name)}" do
          uninstaller(name).uninstall
        end
      end
    end

    # @param name [String]
    # @return [Kontena::PluginManager::Uninstaller]
    def uninstaller(name)
      Kontena::PluginManager::Uninstaller.new(name)
    end
  end
end