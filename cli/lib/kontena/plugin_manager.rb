require 'singleton'

module Kontena
  class PluginManager
    include Singleton

    attr_reader :plugins

    def initialize
      @plugins = []
    end

    # @return [Array<Gem::Specification>]
    def load_plugins
      Gem::Specification.to_a.each do |spec|
        spec.require_paths.to_a.each do |require_path|
          plugin = File.join(spec.gem_dir, require_path, 'kontena_cli_plugin.rb')
          if File.exist?(plugin)
            begin
              load(plugin)
              @plugins << spec
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
