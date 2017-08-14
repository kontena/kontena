require 'kontena/plugin_manager'

module Kontena
  module PluginManager
    module Common
      Gem.autoload :DefaultUserInteraction, 'rubygems/user_interaction'
      Gem.autoload :StreamUI, 'rubygems/user_interaction'

      # @return [Boolean] is the CLI in plugin debugging mode?
      def plugin_debug?
        @plugin_debug ||= ENV['DEBUG'] == 'plugin'
      end
      module_function :plugin_debug?

      # @return [Gem::StreamUI] a rubygems user interaction module with minimal output
      def dummy_ui
        Gem::StreamUI.new(StringIO.new, StringIO.new, StringIO.new, false)
      end
      module_function :dummy_ui

      # Tell rubygems to use the dummy ui as default user interaction
      def use_dummy_ui
        Gem::DefaultUserInteraction.ui = dummy_ui
      end
      module_function :use_dummy_ui

      # Prefix a plugin name into a gem name (hello to kontena-plugin-hello)
      def prefix(plugin_name)
        return plugin_name if plugin_name.to_s.start_with?('kontena-plugin-') || plugin_name.include?('.')
        "kontena-plugin-#{plugin_name}"
      end
      module_function :prefix

      # Find a plugin by name from installed plugins
      # @param plugin_name [String]
      def installed(plugin_name)
        search = prefix(plugin_name)
        plugins.find {|plugin| plugin.name == search }
      end
      module_function :installed

      def installed?(plugin_name)
        !installed(plugin_name).nil?
      end
      module_function :installed?

      # Gem installation directory
      # @return [String]
      def install_dir
        return @install_dir if @install_dir
        install_dir = File.join(Dir.home, '.kontena', 'gems', RUBY_VERSION)
        unless File.directory?(install_dir)
          require 'fileutils'
          FileUtils.mkdir_p(install_dir, mode: 0700)
        end
        @install_dir = install_dir
      end
      module_function :install_dir

      # @return [Kontena::PluginManager::RubygemsClient]
      def rubygems_client
        @rubygems_client ||= Kontena::PluginManager::RubygemsClient.new
      end
      module_function :rubygems_client

      # Search rubygems for kontena plugins
      # @param pattern [String] optional search pattern
      def search_plugins(pattern = nil)
        rubygems_client.search(prefix(pattern))
      end
      module_function :search_plugins

      # Retrieve plugin versions from rubygems
      # @param plugin_name [String]
      def gem_versions(plugin_name)
        rubygems_client.versions(prefix(plugin_name))
      end
      module_function :gem_versions

      def plugins
        Kontena::PluginManager.plugins
      end
      module_function :plugins
    end
  end
end
