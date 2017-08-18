require_relative 'yaml/reader'
require_relative '../services/services_helper'
require_relative 'service_generator_v2'
require_relative '../../stacks_client'
require 'yaml'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Services::ServicesHelper

    module StackNameParam
      attr_accessor :stack_version

      def self.included(where)
        where.parameter "STACK_NAME", "Stack name, for example user/stackname or user/stackname:version" do |name|
          if name.include?(':')
            name, @stack_version = name.split(':',2 )
          end
          name
        end
      end
    end

    module StackFileOrNameParam
      def self.included(where)
        where.parameter "[FILE]", "Kontena stack file, registry stack name (user/stack or user/stack:version) or URL", default: "kontena.yml", attribute_name: :filename
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

      def dump_variables(reader)
        vals = reader.variables.to_h(values_only: true).reject {|k,_| k == 'STACK' || k == 'GRID' }
        File.write(values_to, ::YAML.dump(vals))
      end
    end

    module StackValuesFromOption
      attr_accessor :values
      def self.included(where)
        where.option '--values-from', '[FILE]', 'Read variable values from YAML' do |filename|
          if filename
            require_config_file(filename)
            @values = ::YAML.safe_load(File.read(filename))
          end
          filename
        end
      end
    end

    def stack_name
      @stack_name ||= (self.respond_to?(:name) && self.name) ? self.name : stack_name_from_yaml(filename)
    end
    module_function :stack_name

    def reader_from_yaml(filename, name: nil, values: nil, defaults: nil, skip_envs: false)
      Kontena.logger.debug { "Reader from yaml for #{filename}" }
      reader = Kontena::Cli::Stacks::YAML::Reader.new(filename, values: values, defaults: defaults)
      if reader.stack_name.nil?
        exit_with_error "Stack MUST have stack name in YAML top level field 'stack'! Aborting."
      end
      set_env_variables(name || reader.stack_name, current_grid) unless skip_envs
      reader
    end
    module_function :reader_from_yaml

    def stack_from_reader(reader)
      outcome = reader.execute

      hint_on_validation_notifications(outcome[:notifications]) unless outcome[:notifications].empty?
      abort_on_validation_errors(outcome[:errors]) unless outcome[:errors].empty?
      kontena_services = generate_services(outcome[:services])
      kontena_volumes = generate_volumes(outcome[:volumes])
      stack = {
        'name' => outcome[:name],
        'stack' => outcome[:stack],
        'expose' => outcome[:expose],
        'version' => outcome[:version],
        'source' => reader.raw_content,
        'registry' => outcome[:registry],
        'services' => kontena_services,
        'volumes' => kontena_volumes,
        'variables' => outcome[:variables],
        'dependencies' => outcome[:dependencies]
      }
      stack
    end
    module_function :stack_from_reader

    def stack_from_yaml(filename, name: nil, values: nil, defaults: nil, skip_envs: false)
      reader = reader_from_yaml(filename, name: name, values: values, defaults: defaults, skip_envs: skip_envs)
      stack_from_reader(reader)
    end
    module_function :stack_from_yaml

    def stack_read_and_dump(filename, name: nil, values: nil, defaults: nil)
      reader = reader_from_yaml(filename, name: name, values: values, defaults: defaults)
      stack = stack_from_reader(reader)
      dump_variables(reader) if values_to
      stack
    end

    def require_config_file(filename)
      exit_with_error("File #{filename} does not exist") unless File.exists?(filename)
    end

    def generate_volumes(yaml_volumes)
      return [] unless yaml_volumes
      yaml_volumes.map do |name, config|
        if config['external'].is_a?(TrueClass)
          config['external'] = name
        elsif config['external']['name']
          config['external'] = config['external']['name']
        end
        config.merge('name' => name)
      end
    end
    module_function :generate_volumes

    def generate_services(yaml_services)
      return [] unless yaml_services
      yaml_services.map do |name, config|
        exit_with_error("Image is missing for #{name}. Aborting.") unless config['image'] # why isn't this a validation?
        ServiceGeneratorV2.new(config).generate.merge('name' => name)
      end
    end
    module_function :generate_services

    def set_env_variables(stack, grid)
      ENV['STACK'] = stack
      ENV['GRID'] = grid
      ENV['PLATFORM'] = grid
    end
    module_function :set_env_variables

    # @return [String]
    def current_dir
      File.basename(Dir.getwd)
    end
    module_function :current_dir

    def display_notifications(messages, color = :yellow)
      $stderr.puts(Kontena.pastel.send(color, messages.to_yaml.gsub(/^---$/, '')))
    end
    module_function :display_notifications

    def hint_on_validation_notifications(errors)
      $stderr.puts "YAML contains the following unsupported options and they were rejected:".colorize(:yellow)
      display_notifications(errors)
    end
    module_function :hint_on_validation_notifications

    def abort_on_validation_errors(errors)
      $stderr.puts "YAML validation failed! Aborting.".colorize(:red)
      display_notifications(errors, :red)
      abort
    end
    module_function :abort_on_validation_errors

    def stacks_client
      @stacks_client ||= Kontena::StacksClient.new(current_account.stacks_url, current_account.token, read_requires_token: current_account.stacks_read_authentication)
    end
  end
end
