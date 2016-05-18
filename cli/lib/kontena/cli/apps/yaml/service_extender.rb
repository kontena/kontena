require 'yaml'

module Kontena::Cli::Apps
  module YAML
    class ServiceExtender
      attr_reader :options

      # @param [Hash] options
      def initialize(options)
        @options = options
      end

      # @param [Hash] parent_options
      # @return [Hash]
      def extend(parent_options)
        options['environment'] = extend_env_vars(
          parent_options['environment'],
          options['environment']
        )
        options['secrets'] = extend_secrets(
          parent_options['secrets'],
          options['secrets']
        )
        parent_options.merge(options)
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
    end
  end
end
