require_relative 'stacks_client'
require_relative 'cli/common'
require_relative 'cli/stacks/common'
require 'yaml'
require 'uri'

module Kontena
  class StacksCache
    class CachedStack

      attr_accessor :stack
      attr_accessor :version

      def initialize(stack, version = nil)
        unless version
          stack, version = stack.split(':', 2)
        end
        @stack = stack
        @version = version
      end

      def read
        File.read(path)
      end

      def load
        YAML.safe_load(read)
      end

      def write(content)
        raise ArgumentError, "Stack name and version required" unless @stack && @version
        unless File.directory?(File.dirname(path))
          require 'fileutils'
          FileUtils.mkdir_p(File.dirname(path))
        end
        File.write(path, content)
      end

      def delete
        File.unlink(path)
      end

      def cached?
        return false unless version
        File.exist?(path)
      end

      def path
        path = File.expand_path(File.join(base_path, "#{stack}-#{version}.yml"))
        raise "Path traversal attempted" unless path.start_with?(base_path)
        path
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
      def pull(stack, version = nil)
        cache(stack, version).read
      end

      def dputs(msg)
        ENV["DEBUG"] && $stderr.puts(msg)
      end

      def cache(stack, version = nil)
        stack = CachedStack.new(stack, version)
        if stack.cached?
          dputs "Reading from cache: #{stack.path}"
        else
          dputs "Retrieving #{stack.stack}:#{stack.version} from registry"
          content = client.pull(stack.stack, stack.version)
          yaml    = ::YAML.safe_load(content)
          new_stack = CachedStack.new(yaml['stack'], yaml['version'])
          if new_stack.cached?
            dputs "Already cached"
            stack = new_stack
          else
            stack.stack = yaml['stack']
            stack.version = yaml['version']
            dputs "Writing #{stack.path}"
            stack.write(content)
            dputs "#{stack.stack}:#{stack.version} cached to #{stack.path}"
          end
        end
        stack
      end

      def registry_url(stack, version = nil)
        client.full_uri(stack, version)
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
