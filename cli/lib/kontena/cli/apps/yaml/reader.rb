require 'yaml'
require_relative 'service_extender'
require_relative 'validator'
require_relative 'validator_v2'

module Kontena::Cli::Apps
  module YAML
    class Reader
      attr_reader :yaml, :file, :errors, :notifications

      def initialize(file)
        @file = file
        @errors = []
        @notifications = []
        load_yaml
        validate
      end

      ##
      # @param [String] service_name
      # @return [Hash]
      def execute(service_name = nil)
        result = {}
        Dir.chdir(File.dirname(File.expand_path(file))) do
          result[:version] = yaml['version'] || '1'
          result[:services] = parse_services(service_name)
          result[:errors] = errors
          result[:notifications] = notifications
        end
        result
      end

      ##
      # @return [true|false]
      def v2?
        yaml['version'].to_s == '2'
      end

      private

      def load_yaml
        content = File.read(File.expand_path(file))
        content = content % { project: ENV['project'], grid: ENV['grid'] }
        interpolate(content)
        replace_dollar_dollars(content)
        @yaml = ::YAML.load(content)
      end

      # @return [Array] array of validation errors
      def validate
        result = validator.validate(yaml)
        store_failures(result)
        result
      end

      def store_failures(data)
        errors << { file => data[:errors] } unless data[:errors].empty?
        notifications << { file => data[:notifications] } unless data[:notifications].empty?
      end

      # @return [Kontena::Cli::Apps::YAML::Validator]
      def validator
        if @validator.nil?
          validator_klass = v2? ? YAML::ValidatorV2 : YAML::Validator
          @validator = validator_klass.new
        end
        @validator
      end

      ##
      # @param [String] service_name - optional service to parse
      # @return [Hash]
      def parse_services(service_name = nil)
        if service_name.nil?
          services.each { |name, config| services[name] = process_config(config) }
          services
        else
          abort("Service '#{service_name}' not found in #{file}".colorize(:red)) unless services.key?(service_name)
          process_config(services[service_name])
        end
      end

      # @param [Hash] service_config
      def process_config(service_config)
        normalize_env_vars(service_config)
        service_config = extend_config(service_config) if service_config.key?('extends')
        service_config
      end

      # @return [Hash] - services from YAML file
      def services
        if v2?
          yaml['services']
        else
          yaml
        end
      end

      ##
      # @param [String] text - content of YAML file
      def interpolate(text)
        text.gsub!(/(?<!\$)\$(?!\$)\{?\w+\}?/) do |v| # searches $VAR and ${VAR} and not $$VAR
          var = v.tr('${}', '')
          puts "The #{var} is not set. Substituting an empty string." unless ENV.key?(var)
          ENV[var] # replace with equivalent ENV variables
        end
      end

      ##
      # @param [String] text - content of yaml file
      def replace_dollar_dollars(text)
        text.gsub!('$$', '$')
      end

      # @param [Hash] service_config
      # @return [Hash] updated service config
      def extend_config(service_config)
        service_name = service_config['extends']['service']
        filename = service_config['extends']['file']
        if filename
          parent_service = from_external_file(filename, service_name)
        else
          abort("Service '#{service_name}' not found in #{file}".colorize(:red)) unless services.key?(service_name)
          parent_service = process_config(services[service_name])
        end
        ServiceExtender.new(service_config).extend(parent_service)
      end

      def from_external_file(filename, service_name)
        outcome = Reader.new(filename).execute(service_name)
        errors.concat outcome[:errors] unless errors.any? { |item| item.key?(filename) }
        notifications.concat outcome[:notifications] unless notifications.any? { |item| item.key?(filename) }
        outcome[:services]
      end

      # @param [Hash] options - service config
      def normalize_env_vars(options)
        if options['environment'].is_a?(Hash)
          options['environment'] = options['environment'].map { |k, v| "#{k}=#{v}" }
        end
      end
    end
  end
end
