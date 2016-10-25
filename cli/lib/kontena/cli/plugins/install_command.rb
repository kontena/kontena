require 'open3'

module Kontena::Cli::Plugins
  class InstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'

    option ['-v', '--version'], 'VERSION', 'Specify version of plugin to install'
    option '--pre', :flag, 'Allow pre-release of a plugin to be installed', default: false

    def execute
      install_plugin(name)
    end

    def install_plugin(name)
      plugin = "kontena-plugin-#{name}"
      gem_bin = which('gem')
      install_options = ['--no-ri', '--no-doc']
      install_options << "--version #{version}" if version
      install_options << "--pre" if pre?
      install_command = "#{gem_bin} install #{install_options.join(' ')} #{plugin}"
      success = false
      spinner "installing plugin #{name.colorize(:cyan)}" do
        stdout, stderr, status = Open3.capture3(install_command)
        unless stderr.empty?
          raise stderr
        end
      end
    rescue => exc
      puts exc.message
    end
  end
end
