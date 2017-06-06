require 'singleton'

module Kontena
  class PluginManager
    autoload :RubygemsClient, 'kontena/plugin_manager/rubygems_client'
    Gem.autoload :DependencyInstaller, 'rubygems/dependency_installer'
    Gem.autoload :Requirement, 'rubygems/requirement'
    Gem.autoload :Uninstaller, 'rubygems/uninstaller'
    Gem.autoload :Commands, 'rubygems/command'
    Gem.autoload :DefaultUserInteraction, 'rubygems/user_interaction'
    Gem.autoload :StreamUI, 'rubygems/user_interaction'
    Gem::Commands.autoload :CleanupCommand, 'rubygems/commands/cleanup_command'

    include Singleton

    CLI_GEM = 'kontena-cli'.freeze
    MIN_CLI_VERSION = '0.15.99'.freeze

    # Initialize plugin manager
    def init
      ENV["GEM_HOME"] = install_dir
      Gem.paths = ENV
      plugins
      use_dummy_ui unless ENV["DEBUG"]
      true
    end

    # Install a plugin
    # @param plugin_name [String]
    # @param pre [Boolean] install a prerelease version if available
    # @param version [String] install a specific version
    def install_plugin(plugin_name, pre: false, version: nil)
      cmd = Gem::DependencyInstaller.new(
        document: false,
        force: true,
        prerelease: pre,
        minimal_deps: true
      )
      plugin_version = version.nil? ? Gem::Requirement.default : Gem::Requirement.new(version)
      without_safe { cmd.install(prefix(plugin_name), plugin_version) }
      cmd.installed_gems
    end

    # Uninstall a plugin
    # @param plugin_name [String]
    def uninstall_plugin(plugin_name)
      installed = installed(plugin_name)
      raise "Plugin #{plugin_name} not installed" unless installed

      cmd = Gem::Uninstaller.new(
        installed.name,
        all: true,
        executables: true,
        force: true,
        install_dir: installed.base_dir
      )
      cmd.uninstall
    end

    # Search rubygems for kontena plugins
    # @param pattern [String] optional search pattern
    def search_plugins(pattern = nil)
      RubygemsClient.new.search(prefix(pattern))
    end

    # Retrieve plugin versions from rubygems
    # @param plugin_name [String]
    def gem_versions(plugin_name)
      RubygemsClient.new.versions(prefix(plugin_name))
    end

    # Get the latest version number from rubygems
    # @param plugin_name [String]
    # @param pre [Boolean] include prerelease versions
    def latest_version(plugin_name, pre: false)
      return gem_versions(plugin_name).first if pre
      gem_versions(plugin_name).find { |version| !version.prerelease? }
    end

    # Find a plugin by name from installed plugins
    # @param plugin_name [String]
    def installed(plugin_name)
      search = prefix(plugin_name)
      plugins.find {|plugin| plugin.name == search }
    end

    # Upgrade an installed plugin
    # @param plugin_name [String]
    # @param pre [Boolean] upgrade to a prerelease version if available. Will happen always when the installed version is a prerelease version.
    def upgrade_plugin(plugin_name, pre: false)
      installed = installed(plugin_name)
      if installed.version.prerelease?
        pre = true
      end

      if installed
        latest = latest_version(plugin_name, pre: pre)
        if latest > installed.version
          install_plugin(plugin_name, version: latest.to_s)
        end
      else
        raise "Plugin #{plugin_name} not installed"
      end
    end

    # Runs gem cleanup, removes remains from previous versions
    # @param plugin_name [String]
    def cleanup_plugin(plugin_name)
      cmd = Gem::Commands::CleanupCommand.new
      options = []
      options += ['-q', '--no-verbose'] unless ENV["DEBUG"]
      cmd.handle_options options
      without_safe { cmd.execute }
    rescue Gem::SystemExitException => e
      return true if e.exit_code == 0
      raise
    end

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


    # @return [Array<Gem::Specification>]
    def plugins
      @plugins ||= load_plugins
    end

    private

    # Execute block without SafeYAML. Gem does security internally.
    def without_safe(&block)
      SafeYAML::OPTIONS[:default_mode] = :unsafe if Object.const_defined?(:SafeYAML)
      yield
    ensure
      SafeYAML::OPTIONS[:default_mode] = :safe if Object.const_defined?(:SafeYAML)
    end

    def plugin_debug?
      @plugin_debug ||= ENV['DEBUG'] == 'plugin'
    end

    def load_plugins
      plugins = []
      Gem::Specification.to_a.each do |spec|
        spec.require_paths.to_a.each do |require_path|
          plugin = File.join(spec.gem_dir, require_path, 'kontena_cli_plugin.rb')
          if File.exist?(plugin) && !plugins.find{ |p| p.name == spec.name }
            begin
              if spec_has_valid_dependency?(spec)

                loaded_features_before = $LOADED_FEATURES.dup
                load_path_before = $LOAD_PATH.dup

                Kontena.logger.debug { "Activating plugin #{spec.name}" } if plugin_debug?
                spec.activate
                spec.activate_dependencies

                Kontena.logger.debug { "Loading plugin #{spec.name}" }
                require(plugin)
                Kontena.logger.debug { "Loaded plugin #{spec.name}" } if plugin_debug?

                if plugin_debug?
                  added_features = ($LOADED_FEATURES - loaded_features_before).map {|feat| "- #{feat}"}
                  added_paths = ($LOAD_PATH - load_path_before).map {|feat| "- #{feat}"}
                  Kontena.logger.debug { "Plugin manager loaded features for #{spec.name}:" } unless added_features.empty?
                  added_features.each { |feat| Kontena.logger.debug { feat } }
                  Kontena.logger.debug { "Plugin manager load paths added for #{spec.name}:" } unless added_paths.empty?
                  added_paths.each { |path| Kontena.logger.debug { path } }
                end

                plugins << spec
              else
                plugin_name = spec.name.sub('kontena-plugin-', '')
                $stderr.puts " [#{Kontena.pastel.red('error')}] Plugin #{Kontena.pastel.cyan(plugin_name)} (#{spec.version}) is not compatible with the current cli version."
                $stderr.puts "         To update the plugin, run 'kontena plugin install #{plugin_name}'"
              end
            rescue ScriptError, StandardError => ex
              warn " [#{Kontena.pastel.red('error')}] Failed to load plugin: #{spec.name} from #{spec.gem_dir}\n\tRerun the command with environment DEBUG=true set to get the full exception."
              Kontena.logger.error(ex)
            end
          end
        end
      end
      plugins
    rescue => ex
      $stderr.puts Kontena.pastel.red(ex.message)
      Kontena.logger.error(ex)
    end

    def prefix(plugin_name)
      return plugin_name if plugin_name.to_s.start_with?('kontena-plugin-')
      "kontena-plugin-#{plugin_name}"
    end

    def dummy_ui
      Gem::StreamUI.new(StringIO.new, StringIO.new, StringIO.new, false)
    end

    def use_dummy_ui
      Gem::DefaultUserInteraction.ui = dummy_ui
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
