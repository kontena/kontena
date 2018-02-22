module Kontena
  autoload :StacksClient, 'kontena/stacks_client'

  class StacksCache
    class CachedStack

      attr_reader :stack_name

      def initialize(stack_name)
        @stack_name = stack_name
      end

      def read
        File.read(path)
      end

      def load
        ::YAML.safe_load(read, [], [], true, path)
      end

      def write(content)
        puts "WHATHAT??? #{stack_name.inspect} #{stack_name.version} #{stack_name.stack_name}"
        raise ArgumentError, "Stack name and version required" unless stack_name.stack_name && stack_name.version
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
        return false unless stack_name.version
        File.exist?(path)
      end

      def path
        path = File.expand_path(File.join(base_path, "#{stack_name.stack_name}-#{stack_name.version}.yml"))
        raise "Path traversal attempted" unless path.start_with?(base_path)
        path
      end

      private

      def base_path
        Kontena::StacksCache.base_path
      end
    end

    class RegistryClientFactory
      require 'kontena/cli/common'
      require 'kontena/cli/stacks/common'
      include Kontena::Cli::Common
      include Kontena::Cli::Stacks::Common
    end

    class << self
      def pull(stack_name)
        cache(stack_name).read
      end

      def dputs(msg)
        Kontena.logger.debug { msg }
      end

      def cache(stack_name)
        stack = CachedStack.new(stack_name)
        if stack.cached?
          dputs "Reading from cache: #{stack.path}"
        else
          dputs "Retrieving #{stack.stack_name} from registry"
          content = client.pull(stack_name)
          yaml    = ::YAML.safe_load(content, [], [], true, stack.stack_name.to_s)
          new_stack_name = Kontena::Cli::Stacks::StackName.new(yaml['stack'], yaml['version'])
          puts new_stack_name.inspect
          new_stack = CachedStack.new(new_stack_name)
          if new_stack.cached?
            dputs "Already cached"
            stack = new_stack
          else
            dputs "Writing #{stack.path}"
            new_stack.write(content)
            dputs "#{new_stack.stack_name} cached to #{new_stack.path}"
            stack = new_stack
          end
        end
        stack
      end

      def registry_url(stack_name)
        client.full_uri(stack_name)
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
