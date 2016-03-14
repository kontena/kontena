require 'net/http'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'
require 'vmstat'

module Kontena::Workers
  class NodeInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper

    attr_reader :queue

    PUBLISH_INTERVAL = 60

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
        self.publish_node_stats
      end
    end

    # @param [String] topic
    # @param [Hash] data
    def on_websocket_connected(topic, data)
      self.publish_node_info
      self.publish_node_stats
    end

    def publish_node_info
      info 'publishing node information'
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

    def publish_node_stats
      disk = Vmstat.disk('/')
      load_avg = Vmstat.load_average
      memory = Vmstat.memory
      event = {
          event: 'node:stats',
          data: {
            id: docker_info['ID'],
            memory: {
              wired: memory.wired_bytes,
              active: memory.active_bytes,
              inactive: memory.inactive_bytes,
              free: memory.free_bytes,
              total: memory.total_bytes
            },
            load: {
              :'1m' => load_avg.one_minute,
              :'5m' => load_avg.five_minutes,
              :'15m' => load_avg.fifteen_minutes
            },
            filesystem: [
              {
                name: docker_info['DockerRootDir'],
                free: disk.free_bytes,
                available: disk.available_bytes,
                used: disk.used_bytes,
                total: disk.total_bytes
              }
            ]
          }
      }
      self.queue << event
    end

    # @return [Hash]
    def docker_info
      @docker_info ||= Docker.info
    end
  end
end
