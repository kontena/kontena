require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      confirm unless forced?
      uninstall_plugin(name)
    end

    def uninstall_plugin(name)
      plugin = "kontena-plugin-#{name}"
      gem_bin = which('gem')
      uninstall_command = "#{gem_bin} uninstall -q #{plugin}"
      success = false
      spinner "Uninstalling plugin #{name.colorize(:cyan)}" do
        stdout, stderr, status = Open3.capture3(uninstall_command)
        unless stderr.empty?
          raise stderr
        end
      end
    rescue => exc
      puts exc.message
    end
  end
end
