require_relative '../stack_name'
require 'yaml'
require_relative 'reader'

module Kontena::Cli::Stacks
  module YAML
    class StackFileLoader
      # A base class for loading stack files. You can define more loaders by
      # inheriting from this class.
      #
      # The purpose of StackFileLoader is to provide a generic interface for
      # loading stack YAML's from different sources, such as local files,
      # stack registry or URLs

      def self.inherited(where)
        loaders << where
      end

      def self.loaders
        @loaders ||= []
      end

      # The main interface for getting a new loader
      #
      # @param source [String] stack file source string (filename, url, ..)
      # @param parent [StackFileLoader] define a parent for recursion
      # @return [StackFileLoader]
      def self.for(source, parent = nil)
        loader = loaders.find { |l| l.match?(source, parent) }
        raise "Can't determine stack file origin for '#{source}'" if loader.nil?
        loader.new(source, parent)
      end

      attr_reader :source, :parent

      # @param source [String] stack file source string (filename, url, ..)
      # @param parent [StackFileLoader] define a parent for recursion
      # @return [StackFileLoader]
      def initialize(source, parent = nil)
        @source = source
        @parent = parent
        set_context if respond_to?(:set_context)
      end

      # @return [Hash] a hash parsed from the YAML content
      def yaml
        ::YAML.safe_load(content)
      end

      # @return [String] raw file content
      def content
        @content ||= read_content
      end

      def read_content
        raise "Implement in inheriting class"
      end

      # @return [StackName] an accessor to StackName for the target file
      def stack_name
        @stack_name ||= Kontena::Cli::Stacks::StackName.new(yaml['stack'], yaml['version'])
      end

      # @return [Reader] an accessor to YAML::Reader for the target file
      def reader(*args)
        @reader ||= Reader.new(self, *args)
      end

      # Builds an array of hashes that represent the dependency tree starting
      # from the target file. Unless recurse is set to false, the tree will
      # contain also nested dependencies from any child stacks.
      #
      # @param recurse [TrueClass,FalseClass] recurse child dependencies?
      # @return [Array[Hash]] an array of hashes ('name', 'stack', 'variables', and 'depends')
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
