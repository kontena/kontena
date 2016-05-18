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
      end

      def validate
        result = validator.validate(yaml)
        validation_errors << { file => result } if result.size > 0
      end

      ##
      # @param [String] service to read
      # @return [Hash]
      def execute(service = nil)
        result = {}
        validate
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

      def validator
        if @validator.nil?
          @validator = YAML::Validator.new
        end
        @validator
      end


      ##
      # @param [String] service to parse
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

      def process_service(name, options)
        normalize_env_vars(options)
        options = extend_service(name, options) if options.key?('extends')
        options
      end

      def load_yaml
        content = File.read(File.expand_path(file))
        content = content % { project: ENV['project'], grid: ENV['grid'] }
        interpolate(content)
        replace_dollar_dollars(content)
        @yaml = ::YAML.load(content)
      end

      def services
        if v2?
          yaml['services']
        else
          yaml
        end
      end

      def populate_env_variables(options)
        options.each do |key, value|
          ENV[key.to_s] = value unless ENV.key?(key.to_s)
        end
      end

      ##
      # @param [String] text
      def interpolate(text)
        text.gsub!(/(?<!\$)\$(?!\$)\{?\w+\}?/) do |v| # searches $VAR and ${VAR} and not $$VAR
          var = v.tr('${}', '')
          puts "The #{var} is not set. Substituting an empty string." unless ENV.key?(var)
          ENV[var] # replace with equivalent ENV variables
        end
      end

      ##
      # @param [String] text
      def replace_dollar_dollars(text)
        text.gsub!('$$', '$')
      end

      # @param [String] name
      # @param [Hash] options
      # @return [Hash]
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

      # @param [Hash] options
      def normalize_env_vars(options)
        if options['environment'].is_a?(Hash)
          options['environment'] = options['environment'].map { |k, v| "#{k}=#{v}" }
        end
      end
    end
  end
end
