require 'dry-validation'

module Kontena::Cli::Apps
  module YAML
    class Validator

      VALID_KEYS = %w(
      affinity build dockerfile cap_add cap_drop command deploy env_file environment extends external_links
      image links log_driver log_opt net pid ports volumes volumes_from cpu_shares
      mem_limit memswap_limit privileged stateful instances hooks secrets
      ).freeze

      UNSUPPORTED_KEYS = %w(
      cgroup_parent container_name devices depends_on dns dns_search tmpfs entrypoint
      expose extra_hosts labels logging network_mode networks security_opt stop_signal ulimits volume_driver
      cpu_quota cpuset domainname hostname ipc mac_address
      read_only restart shm_size stdin_open tty user working_dir
      ).freeze

      ##
      # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      def initialize
        @yaml_schema = Dry::Validation.Schema do
          optional('image').maybe(:str?)
          optional('extends').schema do
            key('service').required(:str?)
            optional('file') { str? }
          end
          rule(image_required: ['extends', 'image']) do |extends, image|
            extends.none?.then(image.filled?)
          end
          optional('build') { str? }
          optional('dockerfile') { str? }
          optional('affinity') { array? { each { format?(/(?<=\!|\=)=/) } } }
          optional('stateful') { bool? }
          optional('cap_add') { array? | none? }
          optional('cap_drop') { array? | none? }
          optional('command') { str? | none? }
          optional('cpu_shares') { int? | none? }
          optional('external_links') { array? }
          optional('mem_limit') { int? | str? }
          optional('memswap_limit') { int? | str? }
          optional('environment') { array? | type?(Hash) }
          optional('env_file') { str? | array? }
          optional('instances') { int? }
          optional('links') { array? }
          optional('net') { inclusion?(%w(host bridge)) }
          optional('ports') { array? }
          optional('volumes') { array? }
          optional('volumes_from') { array? }
          optional('deploy').schema do
            optional('strategy') { inclusion?(%w(ha daemon random)) }
            optional('wait_for_port') { int? }
            optional('min_health') { float? }
          end
          optional('hooks').schema do
            optional('post_start').each do
              key('name').required
              key('cmd').required
              key('instances') { int? | eql?('*') }
              optional('oneshot') { bool? }
            end
            optional('pre_build').each do
              key('cmd').required
            end
          end
          optional('log_driver') { str? }
          optional('log_opts') { type?(Hash) }
          optional('secrets').each do
            key('secret').required
            key('name').required
            key('type').required
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

        yaml.each do |service, options|
          key_errors = validate_keys(options)
          option_errors = validate_options(options)
          result[:errors] << { service => option_errors.messages } if option_errors.failure?
          result[:notifications] << { service => key_errors } if key_errors.size > 0
        end
        result
      end

      ##
      # @param [Hash] service_config
      def validate_options(service_config)
        @yaml_schema.call(service_config)
      end

      ##
      # @param [Hash] service_config
      # @return [Array<String>] errors
      def validate_keys(service_config)
        errors = {}
        service_config.keys.each do |key|
          error = validate_key(key)
          errors[key] << error if error
        end
        errors
      end

      ##
      # @param [String] key
      def validate_key(key)
        if UNSUPPORTED_KEYS.include?(key)
          ['unsupported option']
        elsif !VALID_KEYS.include?(key)
          ['invalid option']
        else
          nil
        end
      end
    end
  end
end
