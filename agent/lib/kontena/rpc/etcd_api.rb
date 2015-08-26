require 'etcd'
require 'docker'
require 'active_support/core_ext/hash/keys'

module Kontena
  module Rpc
    class EtcdApi

      attr_reader :etcd

      def initialize
        @etcd = Etcd.client(host: gateway, port: 2379)
      end

      # @param [String] key
      def get(key)
        etcd.get(key)
      end

      # @param [String] key
      # @param [Hash] opts
      def set(key, opts = {})
        etcd.set(key, opts.symbolize_keys).value
      end

      # @param [String] key
      # @param [Hash] opts
      def delete(key, opts = {})
        etcd.delete(key, opts.symbolize_keys)
      end

      private

      ##
      # @return [String, NilClass]
      def gateway
        agent = Docker::Container.get(ENV['KONTENA_AGENT_NAME'] || 'kontena-agent') rescue nil
        if agent
          agent.json['NetworkSettings']['Gateway']
        end
      end
    end
  end
end
