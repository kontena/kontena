require 'open3'

module Kontena::Cli::Plugins
  class InstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'

    option ['-v', '--version'], 'VERSION', 'Specify version of plugin to install'
    option '--pre', :flag, 'Allow pre-release of a plugin to be installed', default: false

    def execute
      require 'shellwords'
      install_plugin(name)
    end

    def install_plugin(name)
      plugin = "kontena-plugin-#{name}"
      uninstall_previous(plugin) if plugin_exists?(plugin)
      install_options = ['--no-ri', '--no-doc']
      install_options << "--version #{version}" if version
      install_options << "--pre" if pre?
      install_options << plugin
      install_command = "#{gem_bin} install #{install_options.shelljoin}"
      ENV["DEBUG"] && STDERR.puts("Running #{install_command}")
      spinner "Installing plugin #{name.colorize(:cyan)}" do
        stdout, stderr, status = Open3.capture3(install_command)
        raise(RuntimeError, stderr) unless status.success?
      end
    end

    def plugin_exists?(name)
      Kontena::PluginManager.instance.plugins.any? { |p| p.name == name}
    end

    def gem_bin
      @gem_bin ||= which('gem')
    end

    def uninstall_previous(name)
      uninstall_command = "#{gem_bin} uninstall -q #{name.shellescape}"
      spinner "Uninstalling previous version of plugin" do
        stdout, stderr, status = Open3.capture3(uninstall_command)
        raise(RuntimeError, stderr) unless status.success?
      end
    end
  end
end
