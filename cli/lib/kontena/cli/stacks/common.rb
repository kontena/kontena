require_relative 'yaml/reader'
require_relative '../services/services_helper'
require_relative 'service_generator_v2'
require_relative '../../stacks_client'
require 'yaml'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Services::ServicesHelper

    def loader
      @loader ||= Kontena::Cli::Stacks::YAML::StackFileLoader.for(source)
    end

    def reader
      @reader ||= loader.reader
    end

    def stack_name
      @stack_name ||= (self.respond_to?(:name) && self.name) ? self.name : loader.stack_name.stack
    end

    def stack
      @stack ||= reader.execute(
        name: stack_name,
        parent_name: self.respond_to?(:parent_name) ? self.parent_name : nil,
        values: (self.respond_to?(:values_from_options) ? self.values_from_options : {})
      )
    end

    module StackNameParam
      def self.included(where)
        where.parameter "STACK_NAME", "Stack name, for example user/stackname or user/stackname:version", attribute_name: :source
      end
    end

    module StackFileOrNameParam
      def self.included(where)
        where.parameter "[FILE]", "Kontena stack file, registry stack name (user/stack or user/stack:version) or URL", default: "kontena.yml", attribute_name: :source
      end
    end

    module StackNameOption
      def self.included(where)
        where.option ['-n', '--name'], 'NAME', 'Define stack name (by default comes from stack file)'
      end
    end

    module StackValuesToOption
      attr_accessor :values
      def self.included(where)
        where.option '--values-to', '[FILE]', 'Output variable values as YAML to file'
      end

      def dump_variables
        File.write(values_to, ::YAML.dump(reader.variable_values, without_defaults: true, without_vault: true))
      end
    end

    module StackValuesFromOption
      def self.included(where)
        where.prepend InstanceMethods

        where.option '--values-from', '[FILE]', 'Read variable values from YAML' do |filename|
          values_from_file.merge!(::YAML.safe_load(File.read(filename)))
          true
        end

        where.option '-v', "VARIABLE=VALUE", "Set stack variable values, example: -v domain=example.com. Can be used multiple times.", multivalued: true, attribute_name: :var_option do |var_pair|
          var_name, var_value = var_pair.split('=', 2)
          values_from_value_options.merge!(::YAML.safe_load(::YAML.dump(var_name => var_value)))
        end
      end

      module InstanceMethods
        def values_from_file
          @values_from_file ||= {}
        end

        def values_from_value_options
          @values_from_value_options ||= {}
        end

        def values_from_options
          @values_from_options ||= values_from_file.merge(values_from_value_options)
        end
      end
    end

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

    def hint_on_validation_notifications(errors)
      $stderr.puts pastel.yellow("YAML contains the following unsupported options and they were rejected:")
      display_notifications(errors)
    end

    def abort_on_validation_errors(errors)
      $stderr.puts pastel.red("YAML validation failed! Aborting.")
      display_notifications(errors, :red)
      abort
    end

    def stacks_client
      @stacks_client ||= Kontena::StacksClient.new(current_account.stacks_url, current_account.token, read_requires_token: current_account.stacks_read_authentication)
    end
  end
end
