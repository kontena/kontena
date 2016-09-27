module Kontena::Cli::Apps::YAML::Validations::CustomValidators
  class AffinitiesValidator < HashValidator::Validator::Base
    def initialize
      super('valid_affinities')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(Array)
        errors[key] = 'affinity must be array'
        return
      end

      invalid_formats = value.find_all { |a| !a.match(/(?<=\!|\=)=/) }
      if invalid_formats.count > 0
        errors[key] = "affinity contains invalid formats: #{invalid_formats.join(', ')}"
      end
    end
  end
end
