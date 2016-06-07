require 'singleton'
require_relative 'plugin'

module Kontena
  class PluginManager
    include Singleton

    def initialize
      @plugins = []
    end

    def register(plugin)
      @plugins << plugin
      load_plugin(plugin)
    end

    # @param [Kontena::Plugin] plugin
    def load_plugin(plugin)
      Kontena::MainCommand.register(plugin.command, plugin.description, plugin.command_class)
    end
  end
end
