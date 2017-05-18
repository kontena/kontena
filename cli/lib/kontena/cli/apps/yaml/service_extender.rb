require_relative '../../../util'

module Kontena::Cli::Apps
  module YAML
    class ServiceExtender
      include Kontena::Util
      attr_reader :service_config

      # @param [Hash] service_config
      def initialize(service_config)
        @service_config = service_config
      end

      # @param [Hash] from
      # @return [Hash]
      def extend(from)
        service_config['environment'] = extend_env_vars(
          from['environment'],
          service_config['environment']
        )
        service_config['secrets'] = extend_secrets(
          from['secrets'],
          service_config['secrets']
        )
        build_args = extend_build_args(safe_dig(from, 'build', 'args'), safe_dig(service_config, 'build', 'args'))
        unless build_args.empty?
          service_config['build'] = {} unless service_config['build']
          service_config['build']['args'] = build_args
        end

        from.merge(service_config)
      end

      private

      # @param [Array] from
      # @param [Array] to
      # @return [Array]
      def extend_env_vars(from, to)
        env_vars = to || []
        if from
          from.each do |env|
            env_vars << env unless to && to.find do |key|
              key.split('=').first == env.split('=').first
            end
          end
        end
        env_vars
      end

      # @param [Array] from
      # @param [Array] to
      # @return [Array]
      def extend_secrets(from, to)
        secrets = to || []
        if from
          from.each do |from_secret|
            secrets << from_secret unless to && to.any? do |to_secret|
              to_secret['secret'] == from_secret['secret']
            end
          end
        end
        secrets
      end

      def extend_build_args(from, to)
        args = to || {}
        if from
          from.each do |k,v|
            args[k] = v unless args.has_key?(k)
          end
        end
        args
      end
    end
  end
end
