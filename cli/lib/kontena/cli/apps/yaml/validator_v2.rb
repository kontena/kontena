require 'hash_validator'
require_relative 'validator'

module Kontena::Cli::Apps
  module YAML
    class ValidatorV2
      require_relative 'validations'
      include Validations

      def initialize
        @schema = common_validations
        @schema['build'] = optional('valid_build')
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
        if yaml.key?('services')
          yaml['services'].each do |service, options|
            unless options.is_a?(Hash)
              result[:errors] << { service => { 'options' => 'must be a mapping not a string'}  }
              next
            end
            option_errors = validate_options(options)
            result[:errors] << { service => option_errors.errors } unless option_errors.valid?
          end
        else
          result[:errors] << { 'file' => 'services missing' }
        end
        if yaml.key?('volumes')
          result[:notifications] << { 'volumes' => 'Kontena does not support volumes yet. To persist data just define service as stateful (stateful: true)' }
        end
        if yaml.key?('networks')
          result[:notifications] << { 'networks' => 'Kontena does not support multiple networks yet. You can reference services with Kontena\'s internal DNS (service_name.kontena.local)' }
        end
        result
      end
    end
  end
end
