require 'singleton'

module Kontena
  class PluginManager
    include Singleton

    MIN_CLI_VERSION = '0.16.0.alpha1'.freeze

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
              kontena_cli = spec.runtime_dependencies.find{ |d| d.name == 'kontena-cli' }
              if !kontena_cli.match?('kontena-cli', MIN_CLI_VERSION)
                load(plugin)
                @plugins << spec
              else
                STDERR.puts " [#{Kontena.pastel.red('error')}] Plugin #{Kontena.pastel.cyan(spec.name)} (#{spec.version}) is not compatible with current cli version."
                STDERR.puts "         To update plugin, run 'kontena plugin install #{spec.name.sub('kontena-plugin-', '')}'"
                abort
              end
            rescue LoadError => exc
              STDERR.puts "failed to load plugin: #{spec.name}"
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
  end
end
