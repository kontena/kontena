require 'open3'

module Kontena::Cli::Plugins
  class InstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'

    option ['-v', '--version'], 'VERSION', 'Specify version of plugin to install'
    option '--pre', :flag, 'Allow pre-release of a plugin to be installed', default: false

    def execute
      ENV["DEBUG"] && STDERR.puts("Running #{install_command}")
      installed = spinner "Installing plugin #{name.colorize(:cyan)}" do |spin|
        begin
          Kontena::PluginManager.instance.install_plugin(name, pre: pre?, version: version)
        rescue => ex
          puts ex.message
          spin.fail
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
