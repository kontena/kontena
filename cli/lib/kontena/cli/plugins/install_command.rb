require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class InstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::PluginManager::Common

    parameter 'NAME', 'Plugin name'

    option ['-v', '--version'], 'VERSION', 'Specify version of plugin to install'
    option '--pre', :flag, 'Allow pre-release of a plugin to be installed', default: false

    def installer
      Kontena::PluginManager::Installer.new(name, pre: pre?, version: version)
    end

    def execute
      if installed?(name)
        installed = spinner "Upgrading plugin #{pastel.cyan(name)}" do
          installer.upgrade
        end

        spinner "Running cleanup" do |spin|
          Kontena::PluginManager::Cleaner.new(name).cleanup
        end
      else
        installed = spinner "Installing plugin #{pastel.cyan(name)}" do
          installer.install
        end
      end

      Array(installed).each do |gem|
        if gem.name.start_with?('kontena-plugin-')
          puts Kontena.pastel.green("Installed plugin #{gem.name.sub('kontena-plugin-', '')} version #{gem.version}")
        else
          puts Kontena.pastel.cyan("Installed dependency #{gem.name} version #{gem.version}")
        end
      end
    end
  end
end
