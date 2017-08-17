require 'kontena_cli'
require 'kontena/plugin_manager/common'

module Kontena
  module PluginManager
    class Loader
      include Common

      CLI_GEM = 'kontena-cli'.freeze
      MIN_CLI_VERSION = '0.15.99'.freeze

      def loaded_plugins
        @loaded_plugins ||= []
      end

      def load_plugins
        Gem::Specification.to_a.each do |spec|
          plugin_path = plugin_require_path(spec)
          next unless plugin_path
          next if loaded_plugins.find { |p| p.name == spec.name }
          load_plugin(plugin_path, spec)
        end
        loaded_plugins
      end

      private

      def load_plugin(path, spec)
        unless spec_has_valid_dependency?(spec)
          plugin_name = spec.name.sub('kontena-plugin-', '')
          $stderr.puts " [#{Kontena.pastel.red('error')}] Plugin #{Kontena.pastel.cyan(plugin_name)} (#{spec.version}) is not compatible with the current cli version."
          $stderr.puts "         To update the plugin, run 'kontena plugin install #{plugin_name}'"
          return false
        end

        start_tracking
        activate(spec)

        Kontena.logger.debug { "Loading plugin #{spec.name} from #{path}" }
        require(path)
        Kontena.logger.debug { "Loaded plugin #{spec.name}" } if plugin_debug?

        report_tracking
        true
      rescue ScriptError, LoadError, StandardError => ex
        warn " [#{Kontena.pastel.red('error')}] Failed to load plugin: #{spec.name} from #{spec.gem_dir}\n\tRerun the command with environment DEBUG=true set to get the full exception."
        Kontena.logger.error(ex)
        spec.description = spec.description + Kontena.pastel.red(" (broken)")
        false
      ensure
        loaded_plugins << spec
      end

      def activate(spec)
        Kontena.logger.debug { "Activating plugin #{spec.name}" } if plugin_debug?
        spec.activate
        spec.activate_dependencies
      end

      # @param [Gem::Specification] spec
      # @return [Boolean]
      def spec_has_valid_dependency?(spec)
        kontena_cli = spec.runtime_dependencies.find{ |d| d.name == CLI_GEM }
        !kontena_cli.match?(CLI_GEM, MIN_CLI_VERSION)
      rescue
        false
      end

      def plugin_require_path(spec)
        paths = spec.require_paths.to_a.map do |require_path|
          File.join(spec.gem_dir, require_path, 'kontena_cli_plugin.rb')
        end
        paths.find { |path| File.exist?(path) }
      end

      def start_tracking
        return unless plugin_debug?
        @loaded_features_before = $LOADED_FEATURES.dup
        @load_path_before = $LOAD_PATH.dup
      end

      def report_tracking
        return unless plugin_debug?
        added_features = ($LOADED_FEATURES - @loaded_features_before).map {|feat| "- #{feat}"}
        added_paths = ($LOAD_PATH - @load_path_before).map {|feat| "- #{feat}"}
        Kontena.logger.debug { "Plugin manager loaded features for #{spec.name}:" } unless added_features.empty?
        added_features.each { |feat| Kontena.logger.debug { feat } }
        Kontena.logger.debug { "Plugin manager load paths added for #{spec.name}:" } unless added_paths.empty?
        added_paths.each { |path| Kontena.logger.debug { path } }
      end
    end
  end
end
