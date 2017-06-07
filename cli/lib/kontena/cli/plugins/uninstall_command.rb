require 'kontena/plugin_manager'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common
    include Kontena::PluginManager::Common

    parameter 'NAME', 'Plugin name'
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def uninstaller
      Kontena::PluginManager::Uninstaller.new(name)
    end

    def execute
      exit_with_error "Plugin #{name} has not been installed" unless installed?(name)
      confirm unless forced?
      spinner "Uninstalling plugin #{pastel.cyan(name)}" do |spin|
        begin
          uninstaller.uninstall
        rescue => ex
          spin.fail
          $stderr.puts pastel.red("#{ex.class.name} : #{ex.message}")
          logger.error(ex)
        end
      end
    end
  end
end
