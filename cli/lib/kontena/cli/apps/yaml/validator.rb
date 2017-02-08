require 'hash_validator'
module Kontena::Cli::Apps
  module YAML
    class Validator
      require_relative 'validations'
      include Validations

      def initialize(need_image=false)
        @schema = common_validations
        @schema['build'] = optional('string')
        @schema['dockerfile'] = optional('string')
        @schema['net'] = optional(%w(host bridge))
        @schema['log_driver'] = optional('string')
        @schema['log_opts'] = optional({})
        Validations::CustomValidators.load
      end

      ##
      # @param [Hash] yaml
      # @return [Array] validation_errors
      def validate(yaml)
        result = {
          errors: [],
          notifications: []
        }
        yaml.each do |service, options|
          unless options.is_a?(Hash)
            result[:errors] << { service => { 'options' => 'must be a mapping not a string'}  }
            next
          end
          option_errors = validate_options(options)
          result[:errors] << { service => option_errors.errors } unless option_errors.valid?
        end
        result
      end
    end
  end
end
