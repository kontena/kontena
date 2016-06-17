require 'dry-validation'
module Kontena::Cli::Apps
  module YAML
    class Validator
      require_relative 'validations'
      include Validations
      
      VALID_KEYS = %w(
      affinity build dockerfile cap_add cap_drop command deploy env_file environment extends external_links
      image links log_driver log_opt net pid ports volumes volumes_from cpu_shares
      mem_limit memswap_limit privileged stateful user instances hooks secrets health_check
      ).freeze

      UNSUPPORTED_KEYS = %w(
      cgroup_parent container_name devices depends_on dns dns_search tmpfs entrypoint
      expose extra_hosts labels logging network_mode networks security_opt stop_signal ulimits volume_driver
      cpu_quota cpuset domainname hostname ipc mac_address
      read_only restart shm_size stdin_open tty working_dir
      ).freeze

      ##
      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      def initialize(need_image=false)
        base = self
        @yaml_schema = Dry::Validation.Schema do
          base.append_common_validations(self)
          optional('build').maybe(:str?)
          optional('dockerfile') { str? }
          optional('net') { inclusion?(%w(host bridge)) }
          optional('log_driver') { str? }
          optional('log_opts') { type?(Hash) }

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

        yaml.each do |service, options|
          key_errors = validate_keys(options)
          option_errors = validate_options(options)
          result[:errors] << { service => option_errors.messages } if option_errors.failure?
          result[:notifications] << { service => key_errors } if key_errors.size > 0
        end
        result
      end
    end
  end
end
