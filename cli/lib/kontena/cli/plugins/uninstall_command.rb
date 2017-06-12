require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'

    def execute
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
