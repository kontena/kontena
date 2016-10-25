module Kontena::Cli::Apps::YAML::Validations::CustomValidators
  class SecretsValidator < HashValidator::Validator::Base
    def initialize
      super('valid_secrets')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(Array)
        errors[key] = 'secrets must be array'
        return
      end
      secret_item_validation = {
        'secret' => 'string',
        'name' => 'string',
        'type' => 'string'
      }
      value.each do |secret|
        HashValidator.validator_for(secret_item_validation).validate(key, secret, secret_item_validation, errors)
      end
    end
  end
end
