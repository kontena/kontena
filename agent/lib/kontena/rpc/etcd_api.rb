require 'etcd'
require 'docker'
require 'active_support/core_ext/hash/keys'
require_relative '../helpers/iface_helper'

module Kontena
  module Rpc
    class EtcdApi
      include Kontena::Helpers::IfaceHelper

      attr_reader :etcd

      def initialize
        @etcd = Etcd.client(host: gateway, port: 2379)
      end

      # @param [String] key
      def get(key, opts = {})
        response = etcd.get(key, opts)
        if response.directory?
          children = []
          map_children_recursive(children, response.node)
          {children: children}
        else
          {value: response.value}
        end

      rescue Etcd::KeyNotFound
        {error: "Key not found"}
      rescue Etcd::Error => exc
        {error: exc.message}
      end

      # @param [String] key
      # @param [Hash] opts
      def set(key, opts = {})
        response = etcd.set(key, opts.symbolize_keys)
        {value: response.value}
      rescue Etcd::NotDir
        {error: "Directory does not exist"}
      rescue Etcd::NotFile
        {error: "Cannot set value to directory"}
      end

      # @param [String] key
      # @param [Hash] opts
      def delete(key, opts = {})
        etcd.delete(key, opts.symbolize_keys)
        {}
      rescue Etcd::KeyNotFound
        {error: "Key not found"}
      rescue Etcd::NotFile
        {error: "Cannot delete a directory"}
      rescue Etcd::Error => exc
        {error: exc.message}
      end

      private

      ##
      # @return [String, NilClass]
      def gateway
        interface_ip('docker0')
      end

      # @param [Array] children
      # @param [Etcd::Node] node
      def map_children_recursive(children, node)
        if node.directory?
          children << node_as_json(node) if node.key
          node.children.map{|c| map_children_recursive(children, c) }
        else
          children << node_as_json(node)
        end
      end

      # @param [Etcd::Node] node
      # @return [Hash]
      def node_as_json(node)
        {
          created_index: node.created_index,
          modified_index: node.modified_index,
          expiration: node.expiration,
          ttl: node.ttl,
          key: node.key,
          value: node.value,
          dir: node.dir
        }
      end
    end
  end
end
