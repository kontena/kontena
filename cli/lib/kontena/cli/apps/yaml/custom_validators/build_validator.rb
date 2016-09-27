module Kontena::Cli::Apps::YAML::Validations::CustomValidators
  class BuildValidator < HashValidator::Validator::Base
    def initialize
      super('valid_build')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(String) || value.is_a?(Hash)
        errors[key] = 'build must be string or hash'
        return
      end
      if value.is_a?(Hash)
        build_validation = {
          'context' => 'string',
          'dockerfile' => HashValidator.optional('string'),
          'args' => HashValidator.optional(-> (value) { value.is_a?(Array) || value.is_a?(Hash) })
        }
        HashValidator.validator_for(build_validation).validate(key, value, build_validation, errors)
      end
    end
  end
end
