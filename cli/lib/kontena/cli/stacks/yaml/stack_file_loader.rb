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
        if loader.nil?
          raise RuntimeError, "Not found: no such file #{source} or invalid uri scheme"
        end
        loader.new(source, parent)
      end

      attr_reader :source, :parent

      # @param source [String] stack file source string (filename, url, ..)
      # @param parent [StackFileLoader] define a parent for recursion
      # @return [StackFileLoader]
      def initialize(source, parent = nil)
        @source = source
        @parent = parent
      end

      # @return [String] a stripped down version of inspect without all the yaml source
      def inspect
        "#<#{self.class.name}:#{object_id} @source=#{source.inspect} @parent=#{parent.nil? ? 'nil' : parent.source}>"
      end

      # @return [Hash] a hash parsed from the YAML content
      def yaml
        @yaml ||= ::YAML.safe_load(content, [], [], true, source)
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
      # @return [Array<Hash>] an array of hashes ('name', 'stack', 'variables', and 'depends')
      def dependencies(recurse: true)
        return @dependencies if @dependencies
        if depends.nil? || depends.empty?
          @dependencies = nil
        else
          @dependencies = depends.map do |name, dependency|
            loader = StackFileLoader.for(dependency['stack'], self)
            deps = { 'name' => name, 'stack' => loader.source, 'variables' => dependency.fetch('variables', Hash.new) }
            if recurse
              child_deps = loader.dependencies
              deps['depends'] = child_deps unless child_deps.nil?
            end
            deps
          end
        end
      end

      def to_h
        {
          'stack' => stack_name.stack_name,
          :loader => self,
        }
      end

      # Returns a non nested hash of all dependencies.
      # Processes :variables hash and moves the related variables to children
      #
      # @param basename [String] installed stack name
      # @param opts [Hash] extra data such as variable lists
      # @return [Hash] { installation_name => { 'name' => installation-name, 'stack' => stack_name, :loader => self }, child_install_name => { ... } }
      def flat_dependencies(basename, opts = {})
        opt_variables = opts[:variables] || {}

        result = {
          basename => self.to_h.merge(opts).merge(
            name: basename,
            variables: opt_variables.reject { |k, _| k.include?('.') }
          )
        }

        depends.each do |as_name, data|
          variables = {}

          opt_variables.select { |k, _| k.start_with?(as_name + '.') }.each do |k,v|
            variables[k.split('.', 2).last] = v
          end

          data['variables'] ||= {}

          loader = StackFileLoader.for(data['stack'], self)
          result.merge!(
           loader.flat_dependencies(
             basename + '-' + as_name,
             variables: data['variables'].merge(variables),
             parent_name: basename
           )
          )
        end

        result
      end

      private

      def depends
        yaml['depends'] || {}
      end
    end
  end
end

Dir[File.expand_path('../stack_file_loader/*.rb', __FILE__)].each { |f| require f }
