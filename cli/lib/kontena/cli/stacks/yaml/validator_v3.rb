require 'hash_validator'

module Kontena::Cli::Stacks
  module YAML
    class ValidatorV3
      require_relative 'validations'
      include Validations

      KNOWN_TOP_LEVEL_KEYS = %i(
        services
        errors
        volumes
        networks
        variables
        stack
        version
        data
        description
        expose
        depends
      )

      def initialize
        @schema = common_validations
        @schema['build'] = optional('stacks_valid_build')
        @schema['depends_on'] = optional('array')
        @schema['network_mode'] = optional(%w(host bridge))
        @schema['logging'] = optional({
          'driver' => optional('string'),
          'options' => optional(-> (value) { value.kind_of?(Hash) })
          })
        Validations::CustomValidators.load
      end

      # borrowed from server/app/helpers/volumes_helpers.rb
      def parse_volume(vol)
        elements = vol.split(':')
        if elements.size >= 2 # Bind mount or volume used
          if elements[0].start_with?('/') && elements[1] && elements[1].start_with?('/') # Bind mount
            {bind_mount: elements[0], path: elements[1], flags: elements[2..-1].join(',')}
          elsif !elements[0].start_with?('/') && elements[1].start_with?('/') # Real volume
            {volume: elements[0], path: elements[1], flags: elements[2..-1].join(',')}
          else
            {error: "volume definition not in right format: #{vol}" }
          end
        elsif elements.size == 1 && elements[0].start_with?('/') # anon volume
          {bind_mount: nil, path: elements[0], flags: nil} # anon vols do not support flags
        else
          {error: "volume definition not in right format: #{vol}" }
        end
      end

      ##
      # @param [Hash] yaml
      # @param [TrueClass|FalseClass] strict
      # @return [Array] validation_errors
      def validate(yaml)
        result = {
          errors: [],
          notifications: []
        }

        yaml.keys.each do |key|
          unless KNOWN_TOP_LEVEL_KEYS.include?(key) || KNOWN_TOP_LEVEL_KEYS.include?(key.to_sym)
            result[:notifications] << { key.to_s => "unknown top level key" }
          end
        end

        if yaml.key?('services')
          if yaml['services'].kind_of?(Hash)
            yaml['services'].each do |service, options|
              unless options.kind_of?(Hash)
                result[:errors] << { 'services' => { service => { 'options' => "must be a mapping not a #{options.class}"}  } }
                next
              end
              option_errors = validate_options(options)
              result[:errors] << { 'services' => { service => option_errors.errors } } unless option_errors.valid?
              if options['volumes']
                mount_path_occurences = Hash.new(0)
                options['volumes'].each do |volume|
                  parsed = parse_volume(volume)
                  if parsed[:error]
                    result[:errors] << { 'services' => { service => { 'volumes' => { volume => parsed[:error] } } } }
                  elsif parsed[:path]
                    mount_path_occurences[parsed[:path]] += 1
                    volume_name = parsed[:volume]
                    if volume_name && !volume_name.start_with?('/')
                      if yaml.key?('volumes')
                        unless yaml['volumes'][volume_name]
                          result[:errors] << { 'services' => { service => { 'volumes' => { volume_name => 'not found in top level volumes list' } } } }
                        end
                      else
                        result[:errors] << { 'services' => { service => { 'volumes' => { volume => 'defines volume name, but file does not contain volumes definitions' } } } }
                      end
                    end
                  else
                    result[:errors] << { 'services' => { service => { 'volumes' => { volume => 'mount point missing' } } } }
                  end
                end
                mount_path_occurences.select {|path, occurences| occurences > 1 }.each do |path, occurences|
                  result[:errors] << { 'services' => { service => { 'volumes' => { path => "mount point defined #{occurences} times" } } } }
                end
              end
            end
          else
            result[:errors] << { 'services' => "must be a mapping, not #{yaml['services'].class}" }
          end
        else
          result[:notifications] << { 'file' => 'does not define any services' }
        end

        if yaml.key?('volumes')
          if yaml['volumes'].kind_of?(Hash)
            yaml['volumes'].each do |volume, options|
              if options.kind_of?(Hash)
                option_errors = validate_volume_options(options)
                unless option_errors.valid?
                  result[:errors] << { 'volumes' => { volume => option_errors.errors } }
                end
              else
                result[:errors] << { 'volumes' => { volume => { 'options' => "must be a mapping, not #{options.class}" } } }
              end
            end
          else
            result[:errors] << { 'volumes' => "must be a mapping, not #{yaml['volumes'].class}" }
          end
        end

        if yaml.key?('networks')
          result[:notifications] << { 'networks' => 'Kontena does not support multiple networks yet. You can reference services with Kontena\'s internal DNS (service_name.kontena.local)' }
        end

        if (yaml['volumes'].nil? || yaml['volumes'].empty?) && (yaml['services'].nil? || yaml['services'].empty?)
          result[:errors] << { 'file' => 'does not list any services or volumes' }
        end

        if yaml.key?('depends')
          unless yaml['depends'].kind_of?(Hash)
            result[:errors] << { 'depends' => "Must be a mapping, not #{yaml['depends'].class}" }
          end

          yaml['depends'].each do |name, dependency_options|
            validator = validate_dependencies(dependency_options)
            result[:errors] << { 'depends' => { name => validator.errors } } unless validator.valid?
            if yaml.key?('services') && yaml['services'][name]
              result[:errors] << { 'depends' => { name => 'is defined both as service and dependency name' } }
            end
          end
        end
        result
      end
    end
  end
end
