require 'dry-validation'
require_relative 'validator'

module Kontena::Cli::Apps
  module YAML
    class ValidatorV2
      require_relative 'validations'
      include Validations

      VALID_KEYS = %w(
      affinity build cap_add cap_drop command deploy depends_on env_file environment extends external_links
      image links logging network_mode pid ports volumes volumes_from cpu_shares
      mem_limit memswap_limit privileged stateful user instances hooks secrets health_check
      ).freeze

      UNSUPPORTED_KEYS = %w(
      cgroup_parent container_name devices dns dns_search tmpfs entrypoint
      expose extra_hosts labels log_driver log_opt net networks security_opt stop_signal ulimits volume_driver
      cpu_quota cpuset domainname hostname ipc mac_address
      read_only restart shm_size stdin_open tty working_dir
      ).freeze

      ##
      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      def initialize
        base = self
        @yaml_schema = Dry::Validation.Schema do
          base.append_common_validations(self)
          optional('build') { str? | type?(Hash) }

          rule(build_hash: ['build']) do |build|
            build.type?(Hash) > build.schema do
              required('context').filled
              optional('dockerfile').value(:str?)
              optional('args') { array? | type?(Hash) }
            end
          end
          optional('depends_on').value(:array?)
          optional('network_mode').value(included_in?: (%w(host bridge)))
          optional('logging').schema do
            optional('driver').value(:str?)
            optional('options') { type?(Hash) }
          end
        end
      end

      ##
      # @param [Hash] yaml
      # @return [Array] validation_errors
      def validate(yaml)
        result = {
          errors: [],
          notifications: []
        }
        if yaml.key?('services')
          yaml['services'].each do |service, options|
            key_errors = validate_keys(options)
            option_errors = validate_options(options)
            result[:errors] << { service => option_errors.messages } if option_errors.failure?
            result[:notifications] << { service => key_errors } if key_errors.size > 0
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
