require 'singleton'

module Kontena
  class PluginManager

    module SayOverride
      def say(*args)
      end
    end

    include Singleton

    CLI_GEM = 'kontena-cli'.freeze
    MIN_CLI_VERSION = '0.15.99'.freeze

    def init
      ENV["GEM_HOME"] = install_dir
      Gem.paths = ENV
      plugins
      use_dummy_ui unless ENV["DEBUG"]
      true
    end

    def install_dir
      return @install_dir if @install_dir
      install_dir = File.join(Dir.home, '.kontena', 'gems', RUBY_VERSION)
      unless File.directory?(install_dir)
        require 'fileutils'
        FileUtils.mkdir_p(install_dir, mode: 0700)
      end
      @install_dir = install_dir
    end

    def without_safe(&block)
      SafeYAML::OPTIONS[:default_mode] = :unsafe if Object.const_defined?(:SafeYAML)
      yield
    ensure
      SafeYAML::OPTIONS[:default_mode] = :safe if Object.const_defined?(:SafeYAML)
    end

    def plugins
      @plugins ||= load_plugins
    end

    # @return [Array<Gem::Specification>]
    def load_plugins
      plugins = []
      Gem::Specification.to_a.each do |spec|
        spec.require_paths.to_a.each do |require_path|
          plugin = File.join(spec.gem_dir, require_path, 'kontena_cli_plugin.rb')
          if File.exist?(plugin) && !plugins.find{ |p| p.name == spec.name }
            begin
              if spec_has_valid_dependency?(spec)
                load(plugin)
                plugins << spec
              else
                plugin_name = spec.name.sub('kontena-plugin-', '')
                STDERR.puts " [#{Kontena.pastel.red('error')}] Plugin #{Kontena.pastel.cyan(plugin_name)} (#{spec.version}) is not compatible with the current cli version."
                STDERR.puts "         To update the plugin, run 'kontena plugin install #{plugin_name}'"
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
      plugins
    rescue => exc
      STDERR.puts exc.message
    end

    def prefix(plugin_name)
      return plugin_name if plugin_name.to_s.start_with?('kontena-plugin-')
      "kontena-plugin-#{plugin_name}"
    end

    def dummy_ui
      Gem::StreamUI.new(StringIO.new, StringIO.new, StringIO.new, false)
    end

    def use_dummy_ui
      require 'rubygems/user_interaction'
      Gem::DefaultUserInteraction.ui = dummy_ui
    end

    def install_plugin(plugin_name, pre: false, version: nil)
      require 'rubygems/dependency_installer'
      require 'rubygems/requirement'

      cmd = Gem::DependencyInstaller.new(
        document: false,
        force: true,
        prerelease: pre,
        minimal_deps: true
      )
      plugin_version = version.nil? ? Gem::Requirement.default : Gem::Requirement.new(version)
      without_safe { cmd.install(prefix(plugin_name), plugin_version) }
      cleanup_plugin(plugin_name)
      cmd.installed_gems
    end

    def uninstall_plugin(plugin_name)
      require 'rubygems/uninstaller'
      cmd = Gem::Uninstaller.new(
        "kontena-plugin-#{plugin_name}",
        all: true,
        executables: true,
        force: true
      )
      cmd.uninstall
    end

    def search_plugins(pattern = nil)
      client = Excon.new('https://rubygems.org')
      response = client.get(
        path: "/api/v1/search.json?query=#{prefix(pattern)}",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )

      JSON.parse(response.body) rescue nil
    end

    def gem_versions(plugin_name)
      client = Excon.new('https://rubygems.org')
      response = client.get(
        path: "/api/v1/versions/#{prefix(plugin_name)}.json",
        headers: {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }
      )
      versions = JSON.parse(response.body)
      versions.map { |version| Gem::Version.new(version["number"]) }.sort.reverse
    end

    def latest_version(plugin_name, pre: false)
      return gem_versions(plugin_name).first if pre
      gem_versions.find { |version| !version.prerelease? }
    end

    def installed_version(plugin_name)
      search = prefix(plugin_name)
      installed = plugins.find {|plugin| plugin.name == search }
      installed ? installed.version : nil
    end

    def upgrade_plugin(plugin_name, pre: false)
      installed = installed_version(plugin_name)
      if installed.prerelease?
        pre = true
      end

      if installed
        latest = latest_version(plugin_name, pre)
        if latest > installed
          install_plugin(plugin_name, version: latest.to_s)
        end
      else
        raise "Plugin #{plugin_name} not installed"
      end
    end

    def cleanup_plugin(plugin_name)
      require 'rubygems/commands/cleanup_command'
      cmd = Gem::Commands::CleanupCommand.new
      cmd.extend SayOverride
      options = ['--norc']
      options += ['-q', '--no-verbose'] unless ENV["DEBUG"]
      cmd.handle_options options
      without_safe { cmd.execute }
    rescue Gem::SystemExitException => e
      return true if e.exit_code == 0
      raise
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
