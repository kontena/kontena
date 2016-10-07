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
          if File.exist?(plugin) && !@plugins.find{ |p| p.name == spec.name }
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

require 'clamp/subcommand/execution'
module Clamp::Subcommand::Execution
  KNOWN_PLUGINS = {
    'aws'          => 'kontena-plugin-aws',
    'azure'        => 'kontena-plugin-azure',
    'vagrant'      => 'kontena-plugin-vagrant',
    'digitalocean' => 'kontena-plugin-digitalocean',
    'packet'       => 'kontena-plugin-packet',
    'upcloud'      => 'kontena-plugin-upcloud'
  }

  def find_subcommand_class(name)
    if KNOWN_PLUGINS.keys.include?(name) && !Kontena::PluginManager.instance.plugins.find {|p| p.name == KNOWN_PLUGINS[name]}
      signal_usage_error("The #{name} plugin has not been installed. Use: kontena plugin install #{name}")
    end
    subcommand_def = self.class.find_subcommand(name) || signal_usage_error(Clamp.message(:no_such_subcommand, :name => name))
    subcommand_def.subcommand_class
  end
end

