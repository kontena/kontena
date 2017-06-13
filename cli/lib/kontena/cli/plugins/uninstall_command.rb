require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'

    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      exit_with_error "Plugin #{pastel.cyan(name)} is not installed" unless Kontena::PluginManager.instance.installed(name) && !ENV['NO_PLUGINS']
      confirm unless forced?
      spinner "Uninstalling plugin #{pastel.cyan(name)}" do |spin|
        begin
          Kontena::PluginManager.instance.uninstall_plugin(name)
        rescue => ex
          $stderr.puts pastel.red("#{ex.class.name} : #{ex.message}")
          logger.error(ex)
          spin.fail
        end
      end
    end
  end
end
