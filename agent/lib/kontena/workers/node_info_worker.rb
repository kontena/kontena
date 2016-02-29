require 'net/http'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'

module Kontena::Workers
  class NodeInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper

    attr_reader :queue

    PUBLISH_INTERVAL = 300

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(queue, autostart = true)
      @queue = queue
      subscribe('websocket:connected', :on_websocket_connected)
      info 'initialized'
      async.start if autostart
    end

    def start
      loop do
        sleep PUBLISH_INTERVAL
        self.publish_node_info
      end
    end

    # @param [String] topic
    # @param [Hash] data
    def on_websocket_connected(topic, data)
      self.publish_node_info
    end

    def publish_node_info
      info 'publishing node information'
      docker_info = Docker.info
      docker_info['PublicIp'] = self.public_ip
      docker_info['PrivateIp'] = self.private_ip
      event = {
          event: 'node:info',
          data: docker_info
      }
      self.queue << event
    rescue => exc
      error "publish_node_info: #{exc.message}"
    end

    ##
    # @return [String, NilClass]
    def public_ip
      Net::HTTP.get('whatismyip.akamai.com', '/')
    rescue => exc
      error "Cannot resolve public ip: #{exc.message}"
      nil
    end

    # @return [String]
    def private_ip
      ip = interface_ip(private_interface)
      unless ip
        ip = interface_ip('eth0')
      end
      ip
    end

    # @return [String]
    def private_interface
      ENV['KONTENA_PEER_INTERFACE'] || 'eth1'
    end
  end
end
