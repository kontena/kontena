require 'net/http'

require_relative '../models/node'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'
require_relative '../helpers/rpc_helper'

module Kontena::Workers
  class NodeInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper

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
      every(PUBLISH_INTERVAL) do
        self.publish_node_info
      end
    end

    # @param [String] topic
    # @param [Hash] node
    def on_node_info(topic, node)
      @node = node
    end

    def publish_node_info
      debug 'publishing node information'
      docker_info['PublicIp'] = self.public_ip
      docker_info['PrivateIp'] = self.private_ip
      docker_info['AgentVersion'] = Kontena::Agent::VERSION
      rpc_client.async.notification('/nodes/update', [docker_info])
    rescue => exc
      error "publish_node_info: #{exc.message}"
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
  end
end
