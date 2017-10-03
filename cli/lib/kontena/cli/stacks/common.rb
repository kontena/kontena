require_relative 'yaml/reader'
require_relative '../services/services_helper'
require_relative 'service_generator_v2'
require_relative '../../stacks_client'
require_relative 'yaml/stack_file_loader'
require 'yaml'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Services::ServicesHelper

    # @return [StackFileLoader] a loader for the stack origin defined through command-line options
    def loader
      @loader ||= loader_class.for(source)
    end

    # @return [YAML::Reader] a YAML reader for the target file
    def reader
      @reader ||= loader.reader
    end

    # Stack name read from -n parameter or the stack file
    # @return [String]
    def stack_name
      @stack_name ||= (self.respond_to?(:name) && self.name) ? self.name : loader.stack_name.stack
    end

    # An accessor to the YAML Reader outcome. Passes parent name, values from command line and
    # the stackname to the reader.
    #
    # @return [Hash]
    def stack
      @stack ||= reader.execute(
        name: stack_name,
        parent_name: self.respond_to?(:parent_name) ? self.parent_name : nil,
        values: (self.respond_to?(:values_from_options) ? self.values_from_options : {})
      )
    end

    # @return [Class] an accessor to StackFileLoader constant, for testing purposes
    def loader_class
      ::Kontena::Cli::Stacks::YAML::StackFileLoader
    end

    module RegistryNameParam
      def stack_name
        @stack_name ||= Kontena::Cli::Stacks::StackName.new(source)
      end

      def self.included(where)
        where.parameter "STACK_NAME", "Stack name, for example user/stackname or user/stackname:version", attribute_name: :source
      end
    end

    module StackNameParam
      # Include to add a STACK_NAME parameter
      def self.included(where)
        where.parameter "STACK_NAME", "Stack name, for example user/stackname or user/stackname:version", attribute_name: :source
      end
    end

    module StackFileOrNameParam
      # Include to add a stack file parameter
      def self.included(where)
        where.parameter "[FILE]", "Kontena stack file, registry stack name (user/stack or user/stack:version) or URL", default: "kontena.yml", attribute_name: :source
      end
    end

    module StackNameOption
      # Include to add a stack name parameter
      def self.included(where)
        where.option ['-n', '--name'], 'NAME', 'Define stack name (by default comes from stack file)'
      end
    end

    module StackValuesToOption
      attr_accessor :values
      # Include to add --values-to variable value dumping feature
      def self.included(where)
        where.option '--values-to', '[FILE]', 'Output variable values as YAML to file'
      end

      # Writes a YAML file from the values received from YAML::Reader to a file defined through
      # the --values-to option
      def dump_variables
        File.write(values_to, ::YAML.dump(reader.variable_values, without_defaults: true, without_vault: true))
      end
    end

    module StackValuesFromOption
      # Include to add --values-from option to read variable values from a YAML file
      # and the -v variable=value option that can be used to pass variable values
      # directly from command line
      def self.included(where)
        where.prepend InstanceMethods

        where.option '--values-from', '[FILE]', 'Read variable values from a YAML file', multivalued: true do |filename|
          values_from_file.merge!(::YAML.safe_load(File.read(filename)))
          filename
        end

        where.option '--values-from-stack', '[STACK_NAME]', 'Read variable values from an installed stack', multivalued: true do |stackname|
          variables = read_values_from_stacks(stackname)
          Kontena.logger.debug { "Received variables from stack #{stackname} on Master: #{variables.inspect}" }
          warn "Stack #{stackname} does not have any values for variables" if variables.empty?
          values_from_installed_stacks.merge!(variables)
          stackname
        end

        where.option '-v', "VARIABLE=VALUE", "Set stack variable values, example: -v domain=example.com. Can be used multiple times.", multivalued: true, attribute_name: :var_option do |var_pair|
          var_name, var_value = var_pair.split('=', 2)
          values_from_value_options.merge!(::YAML.safe_load(::YAML.dump(var_name => var_value)))
        end
      end

      module InstanceMethods
        def read_values_from_stacks(stackname)
          result = {}
          response = client.get("stacks/#{current_grid}/#{stackname}")
          result.merge!(response['variables']) if response['variables']
          if response['children']
            response['children'].each do |child_info|
              result.merge!(
                read_values_from_stacks(child_info['name']).tap do |child_result|
                  child_result.keys.each do |key|
                    new_key = child_info['name'].dup # foofoo-redis-monitor
                    new_key.sub!("#{stackname}-", '') # monitor
                    new_key.concat ".#{key}" # monitor.foovariable
                    child_result[new_key] = child_result.delete(key)
                  end
                end
              )
            end
          end
          result
        end

        def values_from_file
          @values_from_file ||= {}
        end

        def values_from_value_options
          @values_from_value_options ||= {}
        end

        def values_from_installed_stacks
          @values_from_installed_stacks ||= {}
        end

        def values_from_options
          @values_from_options ||= values_from_installed_stacks.merge(values_from_file).merge(values_from_value_options)
        end

        # Transforms a hash
        # dependency_values_from_options('foo.bar' => 1, 'foo')
        #  => { 'bar' => 1 }
        # Used for dependency variable injection
        def dependency_values_from_options(name)
          name_with_dot = name.to_s + '.'
          values_from_options.each_with_object({}) do |kv_pair, obj|
            key = kv_pair.first.to_s
            value = kv_pair.last
            next unless key.start_with?(name_with_dot)
            obj[key.sub(name_with_dot, '')] = value
          end
        end
      end
    end

    # Sets environment variables from parameters
    # @param stack [String] current stack name
    # @param grid [String] current grid name
    # @param platform [String] current platform name, defaults to param grid value
    def set_env_variables(stack, grid, platform = grid)
      ENV['STACK'] = stack
      ENV['GRID'] = grid
      ENV['PLATFORM'] = platform
    end

    # @return [String]
    def current_dir
      File.basename(Dir.getwd)
    end

    def display_notifications(messages, color = :yellow)
      $stderr.puts(pastel.send(color, messages.to_yaml.gsub(/^---$/, '')))
    end

    def hint_on_validation_notifications(notifications, filename = nil)
      return if notifications.nil? || notifications.empty?
      $stderr.puts pastel.yellow("#{"(#{filename}) " if filename}YAML contains the following unsupported options and they were rejected:")
      display_notifications(notifications)
    end

    def abort_on_validation_errors(errors, filename = nil)
      return if errors.nil? || errors.empty?
      $stderr.puts pastel.red("#{"(#{filename}) " if filename} YAML validation failed! Aborting.")
      display_notifications(errors, :red)
      abort
    end

    # An accessor to stack registry client
    # @return [Kontena::StacksClient]
    def stacks_client
      @stacks_client ||= Kontena::StacksClient.new(current_account.stacks_url, current_account.token, read_requires_token: current_account.stacks_read_authentication)
    end
  end
end
