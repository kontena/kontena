module Kontena
  module PluginManager
    autoload :RubygemsClient, 'kontena/plugin_manager/rubygems_client'
    autoload :Loader, 'kontena/plugin_manager/loader'
    autoload :Installer, 'kontena/plugin_manager/installer'
    autoload :Uninstaller, 'kontena/plugin_manager/uninstaller'
    autoload :Cleaner, 'kontena/plugin_manager/cleaner'
    autoload :Common, 'kontena/plugin_manager/common'

    # Initialize plugin manager
    def init
      ENV["GEM_HOME"] = Common.install_dir
      Gem.paths = ENV
      Common.use_dummy_ui unless ENV["DEBUG"]
      plugins
      true
    end
    module_function :init

    # @return [Array<Gem::Specification>]
    def plugins
      @plugins ||= Loader.new.load_plugins
    end
    module_function :plugins
  end
end
