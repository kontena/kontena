module Kontena::Cli::Stacks::YAML::Validations::CustomValidators
  class HooksValidator < HashValidator::Validator::Base
    def initialize
      super('stacks_valid_hooks')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(Hash)
        errors[key] = 'hooks must be array'
        return
      end

      if value['pre_build']
        validate_pre_build_hooks(key, value['pre_build'], errors)
      end

      if value['post_start']
        validate_post_start_hooks(key, value['post_start'], errors)
      end
    end

    def validate_pre_build_hooks(key, pre_build_hooks, errors)
      unless pre_build_hooks.is_a?(Array)
        errors[key] = 'pre_build must be array'
        return
      end
      pre_build_validation = {
        'name' => 'string',
        'cmd' => 'string'
      }
      validator = HashValidator.validator_for(pre_build_validation)
      pre_build_hooks.each do |pre_build|
        validator.validate('hooks.pre_build', pre_build, pre_build_validation, errors)
      end
    end

    def validate_post_start_hooks(key, post_start_hooks, errors)
      unless post_start_hooks.is_a?(Array)
        errors[key] = 'post_start must be array'
        return
      end
      post_start_validation = {
        'name' => 'string',
        'instances' => (-> (value) { value.is_a?(Integer) || value == '*' }),
        'cmd' => 'string',
        'oneshot' => HashValidator.optional('boolean')
      }
      validator = HashValidator.validator_for(post_start_validation)
      post_start_hooks.each do |post_start|
        validator.validate('hooks.post_start', post_start, post_start_validation, errors)
      end
    end
  end
end
