module Kontena::Cli::Stacks::YAML::Validations::CustomValidators
  class CertificatesValidator < HashValidator::Validator::Base
    def initialize
      super('stacks_valid_certificates')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(Array)
        errors[key] = 'certificates must be array'
        return
      end
      certificate_item_validation = {
        'subject' => 'string',
        'name' => 'string',
        'type' => 'string'
      }
      value.each do |certificate|
        HashValidator.validator_for(certificate_item_validation).validate(key, certificate, certificate_item_validation, errors)
      end
    end
  end
end
