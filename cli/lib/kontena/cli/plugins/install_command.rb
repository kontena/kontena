require 'open3'

module Kontena::Cli::Plugins
  class InstallCommand < Kontena::Command
    include Kontena::Util

    parameter 'NAME', 'Plugin name'

    def execute
      install_plugin(name)
    end

    def install_plugin(name)
      plugin = "kontena-plugin-#{name}"
      gem_bin = which('gem')
      install_command = "#{gem_bin} install --no-ri --no-doc #{plugin}"
      success = false
      ShellSpinner "Installing plugin #{name.colorize(:cyan)}" do
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
