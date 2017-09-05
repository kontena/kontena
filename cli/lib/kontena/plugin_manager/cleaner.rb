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

      def command
        @command ||= Gem::Commands::CleanupCommand.new
      end

      # Runs gem cleanup, removes remains from previous versions
      # @param plugin_name [String]
      def cleanup
        options = []
        options += ['-q', '--no-verbose'] unless ENV["DEBUG"]
        command.handle_options options
        command.execute
        true
      rescue Gem::SystemExitException => e
        raise unless e.exit_code.zero?
        true
      end
    end
  end
end
