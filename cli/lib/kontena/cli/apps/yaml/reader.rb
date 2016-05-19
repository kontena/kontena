require 'yaml'
require_relative 'service_extender'
require_relative 'validator'

module Kontena::Cli::Apps
  module YAML
    class Reader
      attr_reader :yaml, :file, :validation_errors

      def initialize(file)
        @file = file
        @validation_errors = []
        load_yaml
        validate unless v2?
      end

      ##
      # @param [String] service to read
      # @return [Hash]
      def execute(service = nil)
        result = {}
        Dir.chdir(File.dirname(File.expand_path(file))) do
          result[:result] = parse_services(service)
        end
        result[:errors] = validation_errors
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
        validation_errors << { file => result } if result.size > 0
      end

      # @return [Kontena::Cli::Apps::YAML::Validator]
      def validator
        if @validator.nil?
          @validator = YAML::Validator.new
        end
        @validator
      end

      ##
      # @param [String] service - optional service to parse
      # @return [Hash]
      def parse_services(service = nil)
        if service.nil?
          services.each do |name, options|
            services[name] = process_service(name, options)
          end
          yaml
        else
          abort("Service '#{service}' not found in #{file}".colorize(:red)) unless services.key?(service)
          process_service(service, services[service])
        end
      end

      # @param [String] name - name of the service
      # @param [Hash] options - service config
      def process_service(name, options)
        normalize_env_vars(options)
        options = extend_service(name, options) if options.key?('extends')
        options
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

      # @param [String] name - name of the service
      # @param [Hash] options - service config
      # @return [Hash] - updated service config
      def extend_service(name, options)
        service = options['extends']['service']
        file_name = options['extends']['file']
        if file_name
          outcome = Reader.new(file_name).execute(service)
          if outcome[:errors].size > 0
            outcome[:errors].each do |errors|
              validation_errors <<  errors
            end
          end
          parent_service = outcome[:result]
        else
          abort("Service '#{service}' not found in #{file}".colorize(:red)) unless services.key?(service)
          parent_service = services[service]
        end
        options.delete('extends')
        ServiceExtender.new(options).extend(parent_service)
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
