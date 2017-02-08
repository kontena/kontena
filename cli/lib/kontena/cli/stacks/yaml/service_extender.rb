require 'yaml'
require_relative '../../../util'

module Kontena::Cli::Stacks
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
      def extend_from(from)
        service_config['environment'] = extend_env_vars(from['environment'], service_config['environment'])
        service_config['secrets']     = extend_secrets( from['secrets'], service_config['secrets'])
        build_args                    = extend_build_args(safe_dig(from, 'build', 'args'), safe_dig(service_config, 'build', 'args'))
        unless build_args.empty?
          service_config['build'] ||= {}
          service_config['build']['args'] = build_args
        end
        from.merge(service_config)
      end

      private

      # Takes two arrays of "key=value" pairs and merges them. Keys in "from"-array
      # will not overwrite keys that already exist in "to"-array.
      #
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

      # Takes two arrays of hashes containing { 'secret' => 'str', 'type' => 'str', 'name' => 'str' }
      # and merges them. 'secret' is the primary key, secrets found in "to" are not overwritten.
      #
      # @param [Array] from
      # @param [Array] to
      # @return [Array]
      def extend_secrets(from, to)
        from ||= []
        to   ||= []
        uniq_from = []
        from.each do |from_hash|
          uniq_from << from_hash unless to.find {|to_hash| from_hash['secret'] == to_hash['secret'] }
        end
        to + uniq_from
      end

      # Basic merge of two hashes, "to" is dominant.
      def extend_build_args(from, to)
        from ||= {}
        to   ||= {}
        from.merge(to)
      end
    end
  end
end
