require 'yaml'
require_relative 'service_extender'
require_relative 'validator_v3'
require_relative '../../../util'

module Kontena::Cli::Stacks
  module YAML
    class Reader
      include Kontena::Util
      attr_reader :yaml, :file, :errors, :notifications

      def initialize(file, skip_validation = false)
        @file = file
        @errors = []
        @notifications = []
        @skip_validation = skip_validation
        parse_yaml
      end

      ##
      # @param [String] service_name
      # @return [Hash]
      def execute(service_name = nil)
        result = {}
        Dir.chdir(File.dirname(File.expand_path(file))) do
          result[:version] = yaml['version'] || '1'
          result[:stack] = yaml['stack']
          result[:name] = self.stack_name
          result[:expose] = yaml['expose']
          result[:errors] = errors
          result[:notifications] = notifications
          result[:services] = parse_services(service_name) unless errors.count > 0
        end
        result
      end

      def reload
        @errors = []
        @notifications = []
        parse_yaml
      end

      def stack_name
        yaml['stack'].split('/').last if yaml['stack']
      end

      # @return [String]
      def raw
        read_content
      end

      private

      def parse_yaml
        load_yaml
        validate unless skip_validation?
      end

      def read_content
        @content ||= File.read(File.expand_path(file))
      end

      def load_yaml
        content = read_content.dup
        interpolate(content)
        replace_dollar_dollars(content)
        begin
          @yaml = ::YAML.load(content)
        rescue Psych::SyntaxError => e
          raise "Error while parsing #{file}".colorize(:red)+ " "+e.message
        end
      end

      # @return [Array] array of validation errors
      def validate
        result = validator.validate(yaml)
        store_failures(result)
        result
      end

      def skip_validation?
        @skip_validation == true
      end

      def store_failures(data)
        errors << { file => data[:errors] } unless data[:errors].empty?
        notifications << { file => data[:notifications] } unless data[:notifications].empty?
      end

      # @return [Kontena::Cli::Stacks::YAML::ValidatorV3]
      def validator
        @validator ||= YAML::ValidatorV3.new
      end

      ##
      # @param [String] service_name - optional service to parse
      # @return [Hash]
      def parse_services(service_name = nil)
        if service_name.nil?
          services.each do |name, config|
            services[name] = process_config(config)
          end
          services
        else
          raise ("Service '#{service_name}' not found in #{file}") unless services.key?(service_name)
          process_config(services[service_name])
        end
      end

      # @param [Hash] service_config
      def process_config(service_config)
        normalize_env_vars(service_config)
        merge_env_vars(service_config)
        expand_build_context(service_config)
        normalize_build_args(service_config)
        service_config = extend_config(service_config) if service_config.key?('extends')
        service_config
      end

      # @return [Hash] - services from YAML file
      def services
        yaml['services']
      end

      ##
      # @param [String] text - content of YAML file
      def interpolate(text)
        text.gsub!(/(?<!\$)\$(?!\$)\{?\w+\}?/) do |v| # searches $VAR and ${VAR} and not $$VAR
          var = v.tr('${}', '')
          puts "The #{var} is not set. Substituting an empty string." if !ENV.key?(var) && !skip_validation?
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
        extended_service = extended_service(service_config['extends'])
        return unless extended_service
        filename = service_config['extends']['file']
        if filename
          parent_config = from_external_file(filename, extended_service)
        else
          raise ("Service '#{extended_service}' not found in #{file}") unless services.key?(extended_service)
          parent_config = process_config(services[extended_service])
        end
        ServiceExtender.new(service_config).extend_from(parent_config)
      end

      def extended_service(extend_config)
        if extend_config.is_a?(Hash)
          extend_config['service']
        elsif extend_config.is_a?(String)
          extend_config
        else
          nil
        end
      end

      def from_external_file(filename, service_name)
        outcome = Reader.new(filename, @skip_validation).execute(service_name)
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

      # @param [Hash] options
      def merge_env_vars(options)
        return options['environment'] unless options['env_file']

        options['env_file'] = [options['env_file']] if options['env_file'].is_a?(String)
        options['environment'] = [] unless options['environment']
        options['env_file'].each do |env_file|
          options['environment'].concat(read_env_file(env_file))
        end
        options.delete('env_file')
        options['environment'].uniq! { |s| s.split('=').first }
      end

      # @param [String] path
      def read_env_file(path)
        File.readlines(path).map { |line| line.strip }.delete_if { |line| line.start_with?('#') || line.empty? }
      end

      def expand_build_context(options)
        if options['build'].is_a?(String)
          options['build'] = File.expand_path(options['build'])
        elsif context = options.dig('build', 'context')
          options['build']['context'] = File.expand_path(context)
        end
      end

      # @param [Hash] options - service config
      def normalize_build_args(options)
        if safe_dig(options, 'build', 'args').is_a?(Array)
          args = options['build']['args'].dup
          options['build']['args'] = {}
          args.each do |arg|
            k,v = arg.split('=')
            options['build']['args'][k] = v
          end
        end
      end
    end
  end
end
