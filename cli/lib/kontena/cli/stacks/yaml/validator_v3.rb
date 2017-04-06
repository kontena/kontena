require 'hash_validator'

module Kontena::Cli::Stacks
  module YAML
    class ValidatorV3
      require_relative 'validations'
      include Validations

      KNOWN_TOP_LEVEL_KEYS = %w(
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
      )

      def initialize
        @schema = common_validations
        @schema['build'] = optional('stacks_valid_build')
        @schema['depends_on'] = optional('array')
        @schema['network_mode'] = optional(%w(host bridge))
        @schema['logging'] = optional({
          'driver' => optional('string'),
          'options' => optional(-> (value) { value.is_a?(Hash) })
          })
        Validations::CustomValidators.load
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

        result[:notifications] += (yaml.keys - KNOWN_TOP_LEVEL_KEYS).map do |key|
          { key => "unknown top level key" }
        end

        if yaml.key?('services')
          if yaml['services'].is_a?(Hash)
            yaml['services'].each do |service, options|
              unless options.is_a?(Hash)
                result[:errors] << { 'services' => { service => { 'options' => "must be a mapping not a #{options.class}"}  } }
                next
              end
              option_errors = validate_options(options)
              result[:errors] << { 'services' => { service => option_errors.errors } } unless option_errors.valid?
              if options['volumes']
                mount_points = options['volumes'].inject(Hash.new(0)) { |hsh, vol| hsh[vol.split(':').last] += 1; hsh }
                mount_points.each do |mount_point, occurences|
                  next unless occurences > 1
                  result[:errors] << { 'services' => { service => { 'volumes' => { mount_point => "mount point defined #{occurences} times" } } } }
                end

                options['volumes'].each do |volume|
                  if volume.include?(':')
                    volume_name, mount_point = volume.split(':', 2)
                    unless mount_point
                      result[:errors] << { 'services' => { service => { 'volumes' => { volume => 'mount point missing' } } } }
                    end
                    if volume_name
                      if yaml.key?('volumes')
                        unless yaml['volumes'][volume_name]
                          result[:errors] << { 'services' => { service => { 'volumes' => { volume_name => 'not found in top level volumes list' } } } }
                        end
                      else
                        result[:errors] << { 'services' => { service => { 'volumes' => { volume => 'defines volume name, but file does not contain volumes definitions' } } } }
                      end
                    end
                  end
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
          if yaml['volumes'].is_a?(Hash)
            yaml['volumes'].each do |volume, options|
              if options.is_a?(Hash)
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
        result
      end
    end
  end
end
