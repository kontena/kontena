module Kontena::Cli::Apps::YAML::Validations::CustomValidators
  class ExtendsValidator < HashValidator::Validator::Base
    def initialize
      super('valid_extends')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(String) || value.is_a?(Hash)
        errors[key] = 'extends must be string or hash'
        return
      end
      if value.is_a?(Hash)
        extends_validation = { 'service' => 'string' }
        extends_validation['file']  = HashValidator.optional('string') if value['file']
        extends_validation['stack'] = HashValidator.optional('string') if value['stack']
        HashValidator.validator_for(extends_validation).validate(key, value, extends_validation, errors)
      end
    end
  end
end
