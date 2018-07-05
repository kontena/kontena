require 'kontena/plugin_manager/common'
require 'rubygems/dependency_installer'
require 'rubygems/requirement'

module Kontena
  module PluginManager
    class Installer
      include Common

      attr_reader :plugin_name, :pre
      attr_accessor :version

      # Create a new instance of plugin installer
      # @param plugin_name [String]
      # @param pre [Boolean] install a prerelease version if available
      # @param version [String] install a specific version
      def initialize(plugin_name, pre: false, version: nil)
        @plugin_name = plugin_name
        @pre = pre
        @version = version
      end

      def pre?
        !!@pre
      end

      def command
        @command ||= Gem::DependencyInstaller.new(
          document: false,
          force: true,
          prerelease: pre,
          minimal_deps: true
        )
      end

      # Install a plugin
      def install
        return install_uri if plugin_name.include?('://')
        plugin_version = version.nil? ? Gem::Requirement.default : Gem::Requirement.new(version)
        command.install(prefix(plugin_name), plugin_version)
        command.installed_gems
      end

      def install_uri
        require 'tempfile'
        require 'open-uri'
        file = Tempfile.new(['kontena_plugin', '.gem'])
        open(plugin_name) do |input|
          file.write input.read
          file.close
        end
        self.class.new(file.path).install
      ensure
        file.unlink
      end

      def available_upgrade
        installed = installed(plugin_name)
        return false unless installed

        pre = installed.version.prerelease?
        latest = rubygems_client.latest_version(prefix(plugin_name), pre: pre? || pre)
        if latest > installed.version
          latest.to_s
        end
      end

      # Upgrade an installed plugin
      def upgrade
        return install if version
        upgrade_to = available_upgrade
        if upgrade_to
          Installer.new(plugin_name, version: upgrade_to).install
        end
      end
    end
  end
end
