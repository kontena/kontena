require 'net/http'
require_relative '../models/node'
require_relative '../helpers/iface_helper'
require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class NodeInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observable
    include Kontena::Helpers::IfaceHelper
    include Kontena::Helpers::RpcHelper

    attr_reader :node

    PUBLISH_INTERVAL = 60

    # @param [Boolean] autostart
    def initialize(autostart = true)
      subscribe('websocket:connected', :on_websocket_connected)
      subscribe('agent:node_info', :on_node_info)
      info 'initialized'
      async.start if autostart
    end

    # @param [String] topic
    # @param [Hash] data
    def on_websocket_connected(topic, data)
      self.publish_node_info
    end

    def start
      loop do
        sleep PUBLISH_INTERVAL
        self.publish_node_info
      end
    end

    # @param [String] topic
    # @param [Node] node
    def on_node_info(topic, node)
      @node = node
      update_observable(node)
    end

    def publish_node_info
      debug 'publishing node information'
      node_info = docker_info.dup
      node_info['PublicIp'] = self.public_ip
      node_info['PrivateIp'] = self.private_ip
      node_info['AgentVersion'] = Kontena::Agent::VERSION
      node_info['Drivers'] = {
        'Volume' => volume_drivers,
        'Network' => network_drivers
      }
      rpc_client.async.request('/nodes/update', [node_info])
    rescue => exc
      error "publish_node_info: #{exc.message}"
    end

    # @return [Array<Hash>]
    def volume_drivers
      drivers = []
      plugins.each do |plugin|
        config = plugin['Config']
        if config.dig('Interface', 'Types').include?('docker.volumedriver/1.0')
          name, version = plugin['Name'].split(':')
          drivers << { name: name, version: version } if plugin['Enabled']
        end
      end
      docker_info.dig('Plugins', 'Volume').to_a.each do |plugin|
        drivers << { name: plugin }
      end

      drivers
    end

    # @return [Array<Hash>]
    def network_drivers
      drivers = []
      plugins.each do |plugin|
        config = plugin['Config']
        if config.dig('Interface', 'Types').include?('docker.networkdriver/1.0')
          name, version = plugin['Name'].split(':')
          drivers << { name: name, version: version } if plugin['Enabled']
        end
      end
      docker_info.dig('Plugins', 'Network').to_a.each do |plugin|
        drivers << { name: plugin }
      end

      drivers
    end

    # @return [Array<Hash>]
    def plugins
      if docker_api_version >= 1.25
        JSON.parse(Docker.connection.get('/plugins'))
      else
        []
      end
    rescue => exc
      warn "cannot fetch docker engine plugins: #{exc.message}"
      []
    end

    ##
    # @return [String, NilClass]
    def public_ip
      if ENV['KONTENA_PUBLIC_IP'].to_s != ''
        ENV['KONTENA_PUBLIC_IP'].to_s.strip
      else
        Net::HTTP.get('whatismyip.akamai.com', '/')
      end
    rescue => exc
      error "Cannot resolve public ip: #{exc.message}"
      nil
    end

    # @return [String]
    def private_ip
      if ENV['KONTENA_PRIVATE_IP'].to_s != ''
        ENV['KONTENA_PRIVATE_IP'].to_s.strip
      else
        interface_ip(private_interface) || interface_ip('eth0')
      end
    end

    # @return [String]
    def private_interface
      ENV['KONTENA_PEER_INTERFACE'] || 'eth1'
    end

    # @return [Hash]
    def docker_info
      @docker_info ||= Docker.info
    end

    # @return [Hash]
    def docker_version
      @docker_version ||= Docker.version
    end

    # @return [Float]
    def docker_api_version
      docker_version["ApiVersion"].to_f
    end
  end
end
