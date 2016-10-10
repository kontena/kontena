require 'singleton'

module Kontena
  class PluginManager
    include Singleton

    CLI_GEM = 'kontena-cli'.freeze
    MIN_CLI_VERSION = '0.15.99'.freeze

    attr_reader :plugins

    def initialize
      @plugins = []
    end

    # @return [Array<Gem::Specification>]
    def load_plugins
      Gem::Specification.to_a.each do |spec|
        spec.require_paths.to_a.each do |require_path|
          plugin = File.join(spec.gem_dir, require_path, 'kontena_cli_plugin.rb')
          if File.exist?(plugin) && !@plugins.find{ |p| p.name == spec.name }
            begin
              if spec_has_valid_dependency?(spec)
                load(plugin)
                @plugins << spec
              else
                plugin_name = spec.name.sub('kontena-plugin-', '')
                STDERR.puts " [#{Kontena.pastel.red('error')}] Plugin #{Kontena.pastel.cyan(plugin_name)} (#{spec.version}) is not compatible with the current cli version."
                STDERR.puts "         To update plugin, run 'kontena plugin install #{plugin_name}'"
              end
            rescue LoadError => exc
              STDERR.puts " [#{Kontena.pastel.red('error')}] Failed to load plugin: #{spec.name}"
              if ENV['DEBUG']
                STDERR.puts exc.message
                STDERR.puts exc.backtrace.join("\n")
              end
              exit 1
            end
          end
        end
      end
      @plugins
    rescue => exc
      STDERR.puts exc.message
    end

    # @param [Gem::Specification] spec
    # @return [Boolean]
    def spec_has_valid_dependency?(spec)
      kontena_cli = spec.runtime_dependencies.find{ |d| d.name == CLI_GEM }
      !kontena_cli.match?(CLI_GEM, MIN_CLI_VERSION)
    rescue
      false
    end
  end
end
