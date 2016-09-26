module Kontena::Cli::Apps::YAML::CustomValidators
  class HooksValidator < HashValidator::Validator::Base
    def initialize
      super('valid_hooks')
    end

    def validate(key, value, validations, errors)
      unless value.is_a?(Hash)
        errors[key] = 'hooks must be array'
        return
      end
      hook_names = value.keys - ['pre_build', 'post_start']
      if value['pre_build']
        unless value['pre_build'].is_a?(Array)
          errors[key] = 'pre_build must be array'
          return
        end
        value['pre_build'].each do |pre_build|
          pre_build_validation = {
            'name' => 'string',
            'cmd' => 'string'
          }
          HashValidator.validator_for(pre_build_validation).validate('hooks.pre_build', pre_build, pre_build_validation, errors)
        end
      end

      if value['post_start']
        unless value['post_start'].is_a?(Array)
          errors["#{key}"] = 'post_start must be array'
          return
        end
        value['post_start'].each do |post_start|

          post_start_validation = {
            'name' => 'string',
            'instances' => (-> (value) { value.is_a?(Integer) || value == '*' }),
            'cmd' => 'string',
            'oneshot' => HashValidator.optional('boolean')
          }
          HashValidator.validator_for(post_start_validation).validate('hooks.post_start', post_start, post_start_validation, errors)
        end
      end
    end
  end
end
