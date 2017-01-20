require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      confirm unless forced?
      spinner "Uninstalling plugin #{name.colorize(:cyan)}" do |spin|
        begin
          Kontena::PluginManager.instance.uninstall_plugin(name)
        rescue => ex
          puts Kontena.pastel.red(ex.message)
          spin.fail
        end
      end
    end
  end
end
