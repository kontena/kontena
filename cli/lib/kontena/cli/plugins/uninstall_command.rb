require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'PLUGIN_NAME', 'Plugin name', attribute_name: :name
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      confirm unless forced?
      spinner "Uninstalling plugin #{pastel.cyan(name)}" do |spin|
        begin
          Kontena::PluginManager.instance.uninstall_plugin(name)
        rescue => ex
          $stderr.puts pastel.red("#{ex.class.name} : #{ex.message}")
          ENV["DEBUG"] && $stderr.puts(ex.backtrace.join("\n  "))
          spin.fail
        end
      end
    end
  end
end
