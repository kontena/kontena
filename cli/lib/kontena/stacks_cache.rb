require_relative 'stacks_client'
require_relative 'cli/common'
require_relative 'cli/stacks/common'

module Kontena
  class StacksCache
    class CachedStack

      attr_reader :stack
      attr_reader :version

      def initialize(stack, version = nil)
        unless version
          stack, version = stack.split(':', 2)
        end
        @stack = stack
        @version = version
        raise ArgumentError, "Stack name and version required" unless @stack && @version
      end

      def read
        File.read(path)
      end

      def load
        YAML.load(read)
      end

      def write(content)
        File.write(path, content)
      end

      def delete
        File.unlink(path)
      end

      def cached?
        File.exist?(path)
      end

      def path
        return @path if @path
        @path = File.expand_path(File.join(base_path, stack, version))
        raise "Path traversal attempted" unless @path.start_with?(base_path)
        @path
      end

      private

      def base_path
        Kontena::StacksCache.base_path
      end
    end

    class RegistryClientFactory
      include Kontena::Cli::Common
      include Kontena::Cli::Stacks::Common
    end

    class << self
      def get(stack, version = nil)
        cache(stack, version).read
      end

      def cache(stack, version = nil)
        stack = CachedStack.new(stack, version)
        stack.write(client.pull(stack.stack, stack.version)) unless stack.cached?
        stack
      end

      def client
        @client ||= RegistryClientFactory.new.stacks_client
      end

      def base_path
        return @base_path if @base_path
        @base_path = File.join(Dir.home, '.kontena/cache/stacks')
        unless File.directory?(@base_path)
          require 'fileutils'
          FileUtils.mkdir_p(@base_path)
        end
        @base_path
      end
    end
  end
end
