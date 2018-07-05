require 'kontena/plugin_manager'
require_relative 'common'

module Kontena::Cli::Plugins
  class UpgradeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common
    include Kontena::PluginManager::Common

    option '--pre', :flag, 'Include pre-release versions'
    option '--silent', :flag, 'Less verbose output'

    def running_verbose?
      !silent?
    end

    def cleanup(*plugins)
      return if plugins.empty?
      vspinner "Running cleanup" do
        plugins.each do |name|
          Kontena::PluginManager::Cleaner.new(name).cleanup
        end
      end
    end

    def installer(name, version: nil)
      Kontena::PluginManager::Installer.new(name, pre: pre?, version: version)
    end

    def upgrade(name, from, to)
      vspinner "Upgrading #{pastel.cyan(name)} from #{pastel.cyan(from)} to #{pastel.cyan(to)}" do
        installer(name, version: to).install
      end
      sputs "Upgraded #{name} from #{from} to #{to}" if silent?
    end

    def execute
      upgradable = {}

      vspinner "Checking for upgrades" do
        plugins.each do |plugin|
          short = short_name(plugin.name)
          available_upgrade = installer(short).available_upgrade
          unless available_upgrade.nil?
            upgradable[short] = { from: plugin.version.to_s, to: available_upgrade }
          end
        end
      end

      if upgradable.empty?
        vputs "Nothing upgraded"
      else
        upgradable.each do |name, data|
          upgrade(name, data[:from], data[:to])
        end
        cleanup(upgradable.keys)
      end
    end
  end
end
