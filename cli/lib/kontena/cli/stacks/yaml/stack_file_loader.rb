require_relative '../stack_name'
require 'yaml'
require_relative 'reader'

module Kontena::Cli::Stacks
  module YAML
    class StackFileLoader

      def self.inherited(where)
        loaders << where
      end

      def self.loaders
        @loaders ||= []
      end

      def self.for(source, parent = nil)
        loader = loaders.find { |l| l.match?(source, parent) }
        raise "Can't determine stack file origin for '#{source}'" if loader.nil?
        loader.new(source, parent)
      end

      attr_reader :source, :parent

      def initialize(source, parent = nil)
        @source = source
        @parent = parent
        set_context if respond_to?(:set_context)
      end

      def yaml
        ::YAML.safe_load(content)
      end

      def content
        @content ||= read_content
      end

      def read_content
        raise "Implement in inheriting class"
      end

      def stack_name
        @stack_name ||= Kontena::Cli::Stacks::StackName.new(yaml['stack'], yaml['version'])
      end

      def reader(*args)
        @reader ||= Reader.new(self, *args)
      end

      def dependencies(recurse: true)
        return @dependencies if @dependencies
        depends = yaml['depends']
        if depends.nil? || depends.empty?
          @dependencies = nil
        else
          @dependencies = depends.map do |name, dependency|
            reader = StackFileLoader.for(dependency['stack'], self)
            deps = { 'name' => name, 'stack' => reader.source, 'variables' => dependency.fetch('variables', Hash.new) }
            if recurse
              child_deps = reader.dependencies
              deps['depends'] = child_deps unless child_deps.nil?
            end
            deps
          end
        end
      end
    end
  end
end

Dir[File.expand_path('../stack_file_loader/*.rb', __FILE__)].each { |f| require f }
