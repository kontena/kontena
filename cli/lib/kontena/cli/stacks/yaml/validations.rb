module Kontena::Cli::Stacks::YAML
 module Validations
   module CustomValidators
     require_relative 'custom_validators/affinities_validator'
     require_relative 'custom_validators/build_validator'
     require_relative 'custom_validators/extends_validator'
     require_relative 'custom_validators/hooks_validator'
     require_relative 'custom_validators/secrets_validator'

     def self.load
       return if @loaded
       HashValidator.append_validator(AffinitiesValidator.new)
       HashValidator.append_validator(BuildValidator.new)
       HashValidator.append_validator(ExtendsValidator.new)
       HashValidator.append_validator(SecretsValidator.new)
       HashValidator.append_validator(HooksValidator.new)
       @loaded = true
     end
   end

   def common_validations
     {
        'image' => optional('string'), # it's optional because some base yml file might contain image option
        'extends' => optional('stacks_valid_extends'),
        'stateful' => optional('boolean'),
        'affinity' => optional('stacks_valid_affinities'),
        'cap_add' => optional('array'),
        'cap_drop' => optional('array'),
        'command' => optional('string'),
        'cpu_shares' => optional('integer'),
        'external_links' => optional('array'),
        'mem_limit' => optional('string'),
        'mem_swaplimit' => optional('string'),
        'environment' => optional(-> (value) { value.is_a?(Array) || value.is_a?(Hash) }),
        'env_file' => optional(-> (value) { value.is_a?(String) || value.is_a?(Array) }),
        'instances' => optional('integer'),
        'links' => optional(-> (value) { value.is_a?(Array) || value.nil? }),
        'ports' => optional('array'),
        'pid' => optional('string'),
        'privileged' => optional('boolean'),
        'user' => optional('string'),
        'volumes' => optional('array'),
        'volumes_from' => optional('array'),
        'secrets' => optional('stacks_valid_secrets'),
        'hooks' => optional('stacks_valid_hooks'),
        'only_if' => optional(-> (value) { value.is_a?(String) || value.is_a?(Hash) || value.is_a?(Array) }),
        'skip_if' => optional(-> (value) { value.is_a?(String) || value.is_a?(Hash) || value.is_a?(Array) }),
        'deploy' => optional({
          'strategy' => optional(%w(ha daemon random)),
          'wait_for_port' => optional('integer'),
          'min_health' => optional('float'),
          'interval' => optional(/^\d+(min|h|d|)$/)
        }),
        'health_check' => optional({
          'protocol' => /^(http|tcp)$/,
          'port' => 'integer',
          'uri' => optional(/\/[\S]*/),
          'timeout' => optional('integer'),
          'interval' => optional('integer'),
          'initial_delay' => optional('integer')
        })
      }
    end

    def optional(type)
      HashValidator.optional(type)
    end

    def validate_options(service_config)
      HashValidator.validate(service_config, @schema, true)
    end

    def validate_volume_options(volume_config)
      HashValidator.validate(volume_config, volume_schema, true)
    end

    def volume_schema
      {
        'external' => optional(-> (value) { value.is_a?(TrueClass) || (value.is_a?(Hash) && value['name'].is_a?(String)) })
      }
    end
  end
end
