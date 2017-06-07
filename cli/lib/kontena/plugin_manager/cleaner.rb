require 'kontena/plugin_manager/common'
require 'rubygems/commands/cleanup_command'

module Kontena
  module PluginManager
    class Cleaner
      include Common

      attr_reader :plugin_name

      def initialize(plugin_name)
        @plugin_name = plugin_name
      end

      # Runs gem cleanup, removes remains from previous versions
      # @param plugin_name [String]
      def cleanup
        cmd = Gem::Commands::CleanupCommand.new
        options = []
        options += ['-q', '--no-verbose'] unless ENV["DEBUG"]
        cmd.handle_options options
        without_safe { cmd.execute }
      rescue Gem::SystemExitException => e
        raise unless e.exit_code.zero?
        true
      end
    end
  end
end
