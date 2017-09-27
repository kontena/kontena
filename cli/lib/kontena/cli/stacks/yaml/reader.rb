require_relative 'stack_file_loader'
require_relative 'service_extender'
require_relative '../service_generator_v2'
require_relative 'validator_v3'
require 'opto'
require 'liquid'
require_relative 'opto'

module Kontena::Cli::Stacks
  module YAML
    module Opto
      module Resolvers; end
      module Setters; end
    end

    class LiquidNull
      # Workaround for nil-valued variables in Liquid templates:
      #   https://github.com/Shopify/liquid/issues/749
      # This is something that we can pass in to `Liquid::Template.render` that gets evaluated as nil.
      # If we pass in a nil value directly, then Liquid ignores it and considers the variable to be undefined.
      def to_liquid
        nil
      end
    end

    class Reader
      # The kontena Stack YAML reader

      include Kontena::Util
      include Kontena::Cli::Common

      attr_reader :file, :loader, :errors, :notifications

      # @param stack_origin [String] a filename, pointer to registry or an URL
      # @return [Reader]
      def initialize(file)
        if file.kind_of?(StackFileLoader)
          @file = file.source
          @loader = file
        else
          @file = file
          @loader = StackFileLoader.for(file)
        end

        @errors           = []
        @notifications    = []
      end

      # @param without_defaults [TrueClass,FalseClass] strip the GRID, STACK, etc from response
      # @param without_vault [TrueClass,FalseClass] strip out any values that are going to or coming from VAULT
      # @return [Hash] a hash of key value pairs representing the values of stack variables
      def variable_values(without_defaults: false, without_vault: false, with_errors: false)
        result = variables.to_h(values_only: true, with_errors: with_errors)
        if without_defaults
          result.delete_if { |k, _| default_envs.key?(k.to_s) || k.to_s == 'PARENT_STACK' }
        end
        if without_vault
          result.delete_if { |k, _| variables.option(k).from.include?('vault') || variables.option(k).to.include?('vault') }
        end
        result
      end

      # Values that are set always when parsing stacks
      # @return [Hash] a hash of key value pairs
      def default_envs
        @default_envs ||= {
          'GRID' => env['GRID'],
          'STACK' => env['STACK'],
          'PLATFORM' => env['PLATFORM'] || env['GRID']
        }
      end

      # Only uses the values from #default_envs to provide a hash from minimally interpolated
      # YAML file. Useful for accessing some parts of the YAML without asking any questions.
      #
      # @return [Hash] minimally interpolated YAMl from the stack file.
      def internals_interpolated_yaml
        @internals_interpolated_yaml ||= ::YAML.safe_load(
          replace_dollar_dollars(
            interpolate(
              raw_content,
              use_opto: false,
              substitutions: default_envs,
              warnings: false
            )
          )
        )
      rescue Psych::SyntaxError => ex
        raise ex, "Error while parsing #{file} : #{ex.message}"
      end

      # Uses variable interpolation, prompts as needed, liquid interpolation
      #
      # @return [Hash] the most commplete stack parsing outcome
      def fully_interpolated_yaml
        return @fully_interpolated_yaml if @fully_interpolated_yaml
        @fully_interpolated_yaml = ::YAML.safe_load(
          replace_dollar_dollars(
            interpolate(
              interpolate_liquid(
                raw_content,
                variable_values
              ),
              use_opto: true,
              raise_on_unknown: true
            )
          )
        )
      rescue Psych::SyntaxError => ex
        raise ex, "Error while parsing #{file} : #{ex.message}"
      end

      # The YAML file raw content
      def raw_content
        loader.content
      end

      # @return [Hash] with zero interpolation/processing. Will mostly fail
      def raw_yaml
        loader.yaml
      end

      # Creates an opto option definition compatible hash from the #default_envs hash
      # @return [Hash]
      def default_envs_to_options
        default_envs.each_with_object({}) { |env, obj| obj[env[0]] = { type: :string, value: env[1] } }
      end

      # Accessor to the Opto variable handler
      # @return [Opto::Group]
      def variables
        @variables ||= ::Opto::Group.new(
          internals_interpolated_yaml.fetch('variables', {}).merge(default_envs_to_options),
          defaults: { from: :env }
        )
      end

      # Accepts a hash of variable_name => variable_value pairs and sets the values as variable default values
      # Used when previous answers are read from master and passed as default values for upgrade.
      # @param defaults [Hash] { 'variable_name' => 'variable_value' }
      def set_variable_defaults(defaults)
        defaults.each do |key, val|
          var = variables.option(key.to_s)
          var.default = val if var
        end
      end

      # Set values from a hash to values of the variables.
      # Used when variable values are read from a file or command line parameters or dependency variable injection
      # @param [Hash] a hash of variable_name => variable_value pairs
      def set_variable_values(values)
        values.each do |key, val|
          var = variables.option(key.to_s)
          var.set(val) if var
        end
      end

      # Creates a set of variables using the 'depends' section. The variable name is the name of the dependency
      # and the variable value is the generated child stack name. For example,.have something like:
      # depends:
      #   redis:
      #     stack: foo/redis
      # you will get a new variable called "redis" and its value will be "this-stack-name-redis".
      # This variable can be used to interpolate for example a hostname to some environment variable:
      # environment:
      #   - "REDIS_HOST=redis.${REDIS}"
      def create_dependency_variables(dependencies, name)
        return if dependencies.nil?
        dependencies.each do |options|
          variables.build_option(name: options['name'].to_s, type: :string, value: "#{name}-#{options['name']}")
          create_dependency_variables(options['depends'], "#{name}.#{options['name']}")
        end
      end

      # If this stack is a part of a dependency chain and has a parent, the variable $PARENT_STACK will
      # interpolate to the name of the parent stack.
      def create_parent_variable(parent_name)
        variables.build_option(name: 'PARENT_STACK', type: :string, value: parent_name)
      end

      # @return [Boolean] did this stack come from a local file?
      def from_file?
        loader.origin == 'file'
      end

      # @param [String] service_name (set when using extends)
      # @param name [String] override stackname (default is to parse it from the YAML, but if you set it through -n it needs to be overriden)
      # @param parent_name [String] parent stack name
      # @param skip_validation [Boolean] skip running validations
      # @param values [Hash] force-set variable values using variable_name => variable_value key pairs
      # @param defaults [Hash] set variable defaults from variable_name => variable_value key pairs
      # @return [Hash]
      def execute(service_name = nil, name: loader.stack_name.stack, parent_name: nil, skip_validation: false, values: nil, defaults: nil)
        set_variable_defaults(defaults) if defaults
        set_variable_values(values) if values
        create_dependency_variables(dependencies, name)
        create_parent_variable(parent_name) if parent_name

        variables.run
        raise RuntimeError, "Variable validation failed: #{variables.errors.inspect} in #{file}" unless variables.valid? || skip_validation

        validate unless skip_validation

        result = {}
        Dir.chdir(from_file? ? File.dirname(File.expand_path(file)) : Dir.pwd) do
          result['stack']         = raw_yaml['stack']
          result['version']       = loader.stack_name.version || '0.0.1'
          result['name']          = name
          result['registry']      = loader.registry
          result['expose']        = fully_interpolated_yaml['expose']
          result['services']      = errors.empty? ? parse_services(service_name) : {}
          result['volumes']       = errors.empty? ? parse_volumes : {}
          result['dependencies']  = dependencies
          result['source']        = raw_content
          result['variables']     = variable_values(without_defaults: true, without_vault: true)
          result['parent_name']   = parent_name
        end
        if service_name.nil?
          result['services'].each do |service|
            errors << { 'services' => { service['name'] => { 'image' => "image is missing" } } } if service['image'].to_s.empty?
          end
        end
        result
      end

      # Returns an array of hashes containing the dependency tree starting from this file
      # @return [Array<Hash>]]
      def dependencies
        @dependencies ||= loader.dependencies
      end

      # Interpolate any Liquid templating in the YAML content
      # @param content [String] file content
      # @param vars [Hash] key-value pairs
      # @return [String]
      # @raise [Liquid::Error]
      def interpolate_liquid(content, vars)
        Liquid::Template.error_mode = :strict
        template = Liquid::Template.parse(content)

        # Wrap nil values in LiquidNull to not have Liquid consider them as undefined
        vars = vars.map {|key, value| [key, value.nil? ? LiquidNull.new : value]}.to_h

        template.render!(vars, strict_variables: true, strict_filters: true)
      end

      # @return [Array<Hash>] array of validation errors
      def validate
        result = validator.validate(fully_interpolated_yaml)
        store_failures(result)
        result
      end

      # @return [Kontena::Cli::Stacks::YAML::ValidatorV3]
      def validator
        @validator ||= YAML::ValidatorV3.new
      end

      def parse_volumes
        volumes.each do |name, config|
          if process_hash?(config)
            volumes[name].delete('only_if')
            volumes[name].delete('skip_if')
            volumes[name] = process_volume(name, config)
          else
            volumes.delete(name)
          end
        end
        volumes.map { |name, vol| vol.merge('name' => name) }
      end

      ##
      # @param [String] service_name - optional service to parse
      # @return [Hash]
      def parse_services(service_name = nil)
        if service_name.nil?
          services.each do |name, config|
            services[name] = process_config(config, name)
            if process_hash?(config)
              services[name].delete('only_if')
              services[name].delete('skip_if')
            else
              services.delete(name)
            end
          end
          services.map { |name, svc| svc.merge('name' => name) }
        else
          raise ("Service '#{service_name}' not found in #{file}") unless services.key?(service_name)
          process_config(services[service_name], service_name)
        end
      end

      # If the supplied hash contains skip_if/only_if conditionals, process that conditional and return true/false
      #
      # @param [Hash]
      # @return [Boolean]
      def process_hash?(hash)
        return true unless hash['skip_if'] || hash['only_if']

        skip_lambdas = normalize_ifs(hash['skip_if'])
        only_lambdas = normalize_ifs(hash['only_if'])

        if skip_lambdas
          return false if skip_lambdas.any? { |s| s.call }
        end

        if only_lambdas
          return false unless only_lambdas.all? { |s| s.call }
        end

        true
      end

      # @param [Hash] service_config
      def process_config(service_config, name=nil)
        normalize_env_vars(service_config)
        merge_env_vars(service_config)
        expand_build_context(service_config)
        normalize_build_args(service_config)
        if service_config.key?('extends')
          service_config = extend_config(service_config)
          service_config.delete('extends')
        end
        if name
          ServiceGeneratorV2.new(service_config).generate.merge('name' => name)
        else
          ServiceGeneratorV2.new(service_config).generate
        end
      end

      def process_volume(name, volume_config)
        return [] if volume_config.nil? || volume_config.empty?
        if volume_config['external'].is_a?(TrueClass)
          volume_config['external'] = name
        elsif volume_config['external']['name']
          volume_config['external'] = volume_config['external']['name']
        end
        volume_config['name'] = name
        volume_config
      end

      def volumes
        @volumes ||= fully_interpolated_yaml.fetch('volumes', {})
      end

      # @return [Hash] - services from YAML file
      def services
        @services ||= fully_interpolated_yaml.fetch('services', {})
      end

      def from_external_file(filename, service_name)
        external_reader = FileLoader.new(filename, loader).reader
        outcome = external_reader.execute(service_name)
        errors.concat external_reader.errors unless external_reader.errors.empty? || errors.include?(external_reader.errors)
        notifications.concat external_reader.notifications unless external_reader.notifications.empty? || notifications.include?(external_reader.notifications)
        outcome['services']
      end

      private

      ##
      # @param [String] content - content of YAML file
      def interpolate(content, use_opto: true, substitutions: {}, raise_on_unknown: false, warnings: true)
        content.split(/[\r\n]/).map.with_index do |row, line_num|
          # skip lines that opto may be interpolating
          if row.strip.start_with?('interpolate:') || row.strip.start_with?('evaluate:')
            row
          else
            row.gsub(/(?<!\$)\$(?!\$)\{?\w+\}?/) do |v| # searches $VAR and ${VAR} and not $$VAR
              var = v.tr('${}', '')

              if use_opto
                opt = variables.option(var)
                if opt.nil?
                  to_env = variables.find { |opt| Array(opt.to[:env]).include?(var) }
                  if to_env
                    val = to_env.value
                  else
                    raise RuntimeError, "Undeclared variable '#{var}' in #{file}:#{line_num} -- #{row}" if raise_on_unknown
                  end
                else
                  val = opt.value
                end
              else
                val = substitutions[var]
              end

              if val && !val.to_s.empty?
                val.to_s =~ /[\r\n\"\'\|]/ ? val.inspect : val.to_s
              else
                puts "Value for #{var} is not set. Substituting with an empty string." if warnings
                ''
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

      # Generates an array of lambdas that return true if a condition is true
      # Possible syntaxes:
      # @example
      #   normalize_ifs( 'wp' )        # lambdas return true if variable wp is not null or false or 'false'
      #   normalize_ifs( wp: 1 )       # lambdas return true if value of wp is 1
      #   normalize_ifs( ['wp, :ws'] )  # lambdas return true if wp and ws are not not null or false or 'false'
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
      # @return [Hash] updated service config
      def extend_config(service_config)
        extends = service_config['extends']
        case extends
        when NilClass
          return
        when String
          raise ("Service '#{extends}' not found in #{file}") unless services.key?(extends)
          parent_config = process_config(services[extends])
        when Hash
          target = extends['file'] || extends['stack']
          parent_config = from_external_file(target, extends['service'])
        else
          raise TypeError, "Extends must be a hash or string"
        end
        ServiceExtender.new(service_config).extend_from(parent_config)
      end

      def store_failures(data)
        data['errors'] ||= data[:errors] || []
        data['notifications'] ||= data[:notifications] || []
        errors << { File.basename(file) => data['errors'] } unless data['errors'].empty?
        notifications << { File.basename(file) => data['notifications'] } unless data['notifications'].empty?
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
        File.readlines(path).map { |line| line.strip }.reject { |line| line.start_with?('#') || line.empty? }
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
        build = options['build']
        return unless build.kind_of?(Hash)
        args = build['args']
        return unless args
        return unless args.kind_of?(Array)
        build.delete('args')
        build['args'] = args.map { |arg| arg.split('=', 2) }.to_h
      end

      def env
        ENV
      end
    end
  end
end
