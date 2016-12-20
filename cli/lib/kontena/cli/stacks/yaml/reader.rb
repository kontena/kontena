require_relative '../../../util'

module Kontena::Cli::Stacks
  module YAML
    class Reader
      include Kontena::Util
      include Kontena::Cli::Common

      attr_reader :file, :raw_content, :result, :errors, :notifications, :variables, :yaml

      def initialize(file, skip_validation: false, skip_variables: false, replace_missing: nil, from_registry: false)
        require 'yaml'
        require_relative 'service_extender'
        require_relative 'validator_v3'
        require 'opto'
        require_relative 'opto/vault_setter'
        require_relative 'opto/vault_resolver'
        require_relative 'opto/prompt_resolver'

        @file = file
        @from_registry = from_registry

        if from_registry?
          require 'shellwords'
          @raw_content = Kontena::StacksCache.pull(file)
          @registry    = Kontena::StacksCache.registry_url
        else
          @raw_content = File.read(File.expand_path(file))
        end

        @errors = []
        @notifications = []
        @skip_validation  = skip_validation
        @skip_variables   = skip_variables
        @replace_missing  = replace_missing
      end

      def from_registry?
        @from_registry == true
      end

      # @return [Opto::Group]
      def variables
        return @variables if @variables
        if yaml && yaml.has_key?('variables')
          variables_yaml = yaml['variables'].to_yaml
          variables_hash = ::YAML.safe_load(replace_dollar_dollars(interpolate(variables_yaml, use_opto: false)))
          @variables = Opto::Group.new(variables_hash, defaults: { from: :env, to: :env })
        else
          @variables = Opto::Group.new(defaults: { from: :env, to: :env })
        end
        @variables
      end

      def parse_variables
        raise RuntimeError, "Variable validation failed: #{variables.errors.inspect}" unless variables.valid?
        variables.run
      end

      ##
      # @param [String] service_name
      # @return [Hash]
      def execute(service_name = nil)
        load_yaml(false)
        parse_variables unless skip_variables?
        load_yaml
        validate unless skip_validation?

        result = {}
        Dir.chdir(from_registry? ? Dir.pwd : File.dirname(File.expand_path(file))) do
          result[:stack]         = yaml['stack']
          result[:version]       = self.stack_version
          result[:name]          = self.stack_name
          result[:registry]      = @registry if from_registry?
          result[:expose]        = yaml['expose']
          result[:errors]        = errors unless skip_validation?
          result[:notifications] = notifications
          result[:services]      = parse_services(service_name) unless errors.count > 0
          result[:variables]     = variables.to_h(values_only: true).reject { |k,_| variables.option(k).to.has_key?(:vault) } unless skip_variables?
        end
        result
      end

      def stack_name
        yaml = ::YAML.safe_load(raw_content)
        yaml['stack'].split('/').last.split(':').first if yaml['stack']
      end

      def stack_version
        yaml['version'] || yaml['stack'].to_s[/:(.*)/, 1] || '1'
      end

      private

      # A hash such as { "${MYSQL_IMAGE}" => "MYSQL_IMAGE } where the key is the
      # string to be substituted and value is the pure name part
      # @return [Hash]
      def yaml_substitutables
        @content_variables ||= raw_content.scan(/((?<!\$)\$(?!\$)\{?(\w+)\}?)/m)
      end

      def load_yaml(interpolate = true)
        if interpolate
          @yaml = ::YAML.safe_load(replace_dollar_dollars(interpolate(raw_content)))
        else
          @yaml = ::YAML.safe_load(raw_content)
        end
      rescue Psych::SyntaxError => e
        raise "Error while parsing #{file}".colorize(:red)+ " "+e.message
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

      def skip_variables?
        @skip_variables == true
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
            if process_service?(config)
              services[name].delete('only_if')
              services[name].delete('skip_if')
            else
              services.delete(name)
            end
          end
          services
        else
          raise ("Service '#{service_name}' not found in #{file}") unless services.has_key?(service_name)
          process_config(services[service_name])
        end
      end

      def process_service?(config)
        return true unless config['skip_if'] || config['only_if']
        return true if skip_variables? || variables.empty?

        skip_lambdas = normalize_ifs(config['skip_if'])
        only_lambdas = normalize_ifs(config['only_if'])

        if skip_lambdas
          return false if skip_lambdas.any? { |s| s.call }
        end

        if only_lambdas
          return false unless only_lambdas.all? { |s| s.call }
        end

        true
      end

      # Generates an array of lambdas that return true if a condition is true
      # Possible syntaxes:
      # @example
      #   normalize_ifs( 'wp' )        # lambdas return true if variable wp is not null or false or 'false'
      #   normalize_ifs( wp: 1 )       # lambdas return true if value of wp is 1
      #   normalize_ifs( [:wp, :ws] )  # lambdas return true if wp and ws are not not null or false or 'false'
      #   normalize_ifs( wp: 1, ws: 1) # lambdas return true if wp and ws are 1
      #   normalize_ifs(nil)           # returns nil
      def normalize_ifs(ifs)
        case ifs
        when NilClass
          nil
        when Array
          ifs.map do |iff|
            lambda { val = variables.value_of(iff.to_s); !val.nil? && !val.kind_of?(FalseClass) && val != 'false' }
          end
        when Hash
          ifs.each_with_object([]) do |(k, v), arr|
            arr << lambda { variables.value_of(k.to_s) == v }
          end
        when String, Symbol
          [lambda { val = variables.value_of(ifs.to_s); !val.nil? && !val.kind_of?(FalseClass) && val != 'false' }]
        else
          raise TypeError, "Invalid syntax for if: #{ifs.inspect}"
        end
      end

      # @param [Hash] service_config
      def process_config(service_config)
        normalize_env_vars(service_config)
        merge_env_vars(service_config)
        expand_build_context(service_config)
        normalize_build_args(service_config)
        if service_config.has_key?('extends')
          service_config = extend_config(service_config)
          service_config.delete('extends')
        end
        service_config
      end

      # @return [Hash] - services from YAML file
      def services
        yaml['services']
      end

      ##
      # @param [String] text - content of YAML file
      def interpolate(text, use_opto: true)
        text.split(/[\r\n]/).map do |row|
          # skip lines that opto is interpolating
          if row.strip.start_with?('interpolate:') || row.strip.start_with?('evaluate:')
            row
          else
            row.gsub(/(?<!\$)\$(?!\$)\{?\w+\}?/) do |v| # searches $VAR and ${VAR} and not $$VAR
              var = v.tr('${}', '')

              if use_opto
                val = variables.value_of(var) || ENV[var]
              else
                val = ENV[var]
              end

              if val
                val.to_s =~ /[\r\n\"\'\|]/ ? val.inspect : val
              else
                puts "Value for #{var} is not set. Substituting with an empty string." unless skip_validation?
                @replace_missing || ''
              end
            end
          end
        end.join("\n")
      end

      ##
      # @param [String] text - content of yaml file
      def replace_dollar_dollars(text)
        text.gsub('$$', '$')
      end

      # @param [Hash] service_config
      # @return [Hash] updated service config
      def extend_config(service_config)
        extended_service = extended_service(service_config['extends'])
        return unless extended_service
        filename  = service_config['extends']['file']
        stackname = service_config['extends']['stack']
        if filename
          parent_config = from_external_file(filename, extended_service)
        elsif stackname
          parent_config = from_external_file(stackname, extended_service, from_registry: true)
        else
          raise ("Service '#{extended_service}' not found in #{file}") unless services.has_key?(extended_service)
          parent_config = process_config(services[extended_service])
        end
        ServiceExtender.new(service_config).extend_from(parent_config)
      end

      def extended_service(extend_config)
        if extend_config.kind_of?(Hash)
          extend_config['service']
        elsif extend_config.kind_of?(String)
          extend_config
        else
          nil
        end
      end

      def from_external_file(filename, service_name, from_registry: false)
        outcome = Reader.new(filename, skip_validation: @skip_validation, skip_variables: true, replace_missing: @replace_missing, from_registry: from_registry).execute(service_name)
        errors.concat outcome[:errors] unless errors.any? { |item| item.has_key?(filename) }
        notifications.concat outcome[:notifications] unless notifications.any? { |item| item.has_key?(filename) }
        outcome[:services]
      end

      # @param [Hash] options - service config
      def normalize_env_vars(options)
        if options['environment'].kind_of?(Hash)
          options['environment'] = options['environment'].map { |k, v| "#{k}=#{v}" }
        end
      end

      # @param [Hash] options
      def merge_env_vars(options)
        return options['environment'] unless options['env_file']

        options['env_file'] = [options['env_file']] if options['env_file'].kind_of?(String)
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
        if options['build'].kind_of?(String)
          options['build'] = File.expand_path(options['build'])
        elsif context = safe_dig(options, 'build', 'context')
          options['build']['context'] = File.expand_path(context)
        end
      end

      # @param [Hash] options - service config
      def normalize_build_args(options)
        if safe_dig(options, 'build', 'args').kind_of?(Array)
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
