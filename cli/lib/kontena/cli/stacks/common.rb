require_relative 'yaml/reader'
require_relative '../services/services_helper'
require_relative 'service_generator_v2'
require_relative '../../stacks_client'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Services::ServicesHelper

    module StackNameParamWithKontenaYmlFallback
      def self.included(where)
        where.class_eval do
          parameter "[NAME]", "Stack name (default: read from kontena.yml)" do |name|
            name == '.' ? nil : name
          end

          def default_name
            if File.exist?('kontena.yml') && File.readable?('kontena.yml')
              name = ::YAML.safe_load(File.read('kontena.yml'))['stack'].split('/').last
              ENV["DEBUG"] && STDERR.puts("Using stack name #{pastel.cyan(name)} from #{pastel.yellow('kontena.yml')}")
              name
            else
              exit_with_error 'Stack name required'
            end
          rescue
            exit_with_error 'Stack name required'
          end
        end
      end
    end

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
      @stack_name ||= self.name || stack_name_from_yaml(filename)
    end

    def reader_from_yaml(filename, name: nil, values: nil, defaults: nil)
      reader = Kontena::Cli::Stacks::YAML::Reader.new(filename, values: values, defaults: defaults)
      if reader.stack_name.nil?
        exit_with_error "Stack MUST have stack name in YAML top level field 'stack'! Aborting."
      end
      set_env_variables(name || reader.stack_name, current_grid)
      reader
    end

    def stack_from_yaml(filename, name: nil, values: nil, defaults: nil)
      reader = reader_from_yaml(filename, name: name, values: values, defaults: defaults)
      outcome = reader.execute

      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0
      kontena_services = generate_services(outcome[:services], outcome[:version])
      stack = {
        'name' => outcome[:name],
        'stack' => outcome[:stack],
        'expose' => outcome[:expose],
        'version' => outcome[:version],
        'source' => reader.raw_content,
        'registry' => outcome[:registry],
        'services' => kontena_services,
        'variables' => outcome[:variables]
      }
      stack
    end

    def require_config_file(filename)
      exit_with_error("File #{filename} does not exist") unless File.exists?(filename)
    end


    ##
    # @param [Hash] yaml
    # @param [String] version
    # @return [Hash]
    def generate_services(yaml_services, version)
      services = []
      generator_klass = ServiceGeneratorV2
      yaml_services.each do |service_name, config|
        exit_with_error("Image is missing for #{service_name}. Aborting.") unless config['image']
        service = generator_klass.new(config).generate
        service['name'] = service_name
        services << service
      end
      services
    end

    def set_env_variables(stack, grid)
      ENV['STACK'] = stack
      ENV['GRID'] = grid
    end

    # @return [String]
    def current_dir
      File.basename(Dir.getwd)
    end

    def display_notifications(messages, color = :yellow)
      messages.each do |files|
        files.each do |file, services|
          STDERR.puts "#{file}:".colorize(color)
          services.each do |service|
            service.each do |name, errors|
              STDERR.puts "  #{name}:".colorize(color)
              if errors.is_a?(String)
                STDERR.puts "    - #{errors}".colorize(color)
              else
                errors.each do |key, error|
                  STDERR.puts "    - #{key}: #{error.to_json}".colorize(color)
                end
              end
            end
          end
        end
      end
    end

    def hint_on_validation_notifications(errors)
      STDERR.puts "YAML contains the following unsupported options and they were rejected:".colorize(:yellow)
      display_notifications(errors)
    end

    def abort_on_validation_errors(errors)
      STDERR.puts "YAML validation failed! Aborting.".colorize(:red)
      display_notifications(errors, :red)
      abort
    end

    def stacks_client
      return @stacks_client if @stacks_client
      Kontena.run('cloud login') unless cloud_auth?
      config.reset_instance
      @stacks_client = Kontena::StacksClient.new(kontena_account.stacks_url, kontena_account.token)
    end
  end
end
