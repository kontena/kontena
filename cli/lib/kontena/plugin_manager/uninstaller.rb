require 'rubygems/uninstaller'

module Kontena
  module PluginManager
    class Uninstaller
      include PluginManager::Common

      attr_reader :plugin_name

      def initialize(plugin_name)
        @plugin_name = plugin_name
      end

      def command(spec)
        @command ||= Gem::Uninstaller.new(
          spec.name,
          all: true,
          executables: true,
          force: true,
          install_dir: spec.base_dir
        )
      end

      # Uninstall a plugin
      # @param plugin_name [String]
      def uninstall
        installed = installed(plugin_name)
        raise "Plugin #{plugin_name} not installed" unless installed

        command(installed).uninstall
      end
    end
  end
end
