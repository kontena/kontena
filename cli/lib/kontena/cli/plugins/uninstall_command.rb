require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      confirm unless forced?
      uninstall_plugin(name)
    end

    def uninstall_plugin(name)
      plugin = "kontena-plugin-#{name}"
      gem_bin = `which gem`.strip
      install_command = "#{gem_bin} install -q #{plugin}"
      success = false
      ShellSpinner "Uninstalling plugin #{name.colorize(:cyan)}" do
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
