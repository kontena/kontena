require 'open3'

module Kontena::Cli::Plugins
  class UninstallCommand < Kontena::Command
    include Kontena::Util
    include Kontena::Cli::Common

    parameter 'NAME', 'Plugin name'
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require 'shellwords'
      confirm unless forced?
      uninstall_plugin(name)
    end

    def uninstall_plugin(name)
      plugin = "kontena-plugin-#{name}"
      gem_bin = which('gem')
      uninstall_command = "#{gem_bin} uninstall -q #{plugin.shellescape}"
      stderr = spinner "Uninstalling plugin #{name.colorize(:cyan)}" do |spin|
        stdout, stderr, status = Open3.capture3(uninstall_command)
        raise(RuntimeError, stderr) unless status.success?
      end
    end
  end
end
