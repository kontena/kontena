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

    attr_reader :queue, :statsd

    PUBLISH_INTERVAL = 60

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(queue, autostart = true)
      @queue = queue
      @statsd = nil
      subscribe('websocket:connected', :on_websocket_connected)
      subscribe('agent:node_info', :on_node_info)
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

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      statsd_conf = info.dig('grid', 'stats', 'statsd')
      if statsd_conf
        info "exporting stats via statsd to udp://#{statsd_conf['server']}:#{statsd_conf['port']}"
        @statsd = Statsd.new(
          statsd_conf['server'], statsd_conf['port'].to_i || 8125
        ).tap{|sd| sd.namespace = info.dig('grid', 'name')}
      else
        @statsd = nil
      end
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

    def publish_node_stats
      disk = Vmstat.disk('/')
      load_avg = Vmstat.load_average
      event = {
          event: 'node:stats',
          data: {
            id: docker_info['ID'],
            memory: calculate_memory,
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
      send_statsd_metrics(event[:data])
    end

    # @param [Hash] event
    def send_statsd_metrics(event)
      return unless statsd
      key_base = "#{docker_info['Name']}"
      statsd.gauge("#{key_base}.cpu.load.1m", event[:load][:'1m'])
      statsd.gauge("#{key_base}.cpu.load.5m", event[:load][:'5m'])
      statsd.gauge("#{key_base}.cpu.load.15m", event[:load][:'15m'])
      statsd.gauge("#{key_base}.memory.active", event[:memory][:active])
      statsd.gauge("#{key_base}.memory.free", event[:memory][:free])
      statsd.gauge("#{key_base}.memory.total", event[:memory][:total])
      event[:filesystem].each do |fs|
        name = fs[:name].split("/")[1..-1].join(".")
        statsd.gauge("#{key_base}.filesystem.#{name}.free", fs[:free])
        statsd.gauge("#{key_base}.filesystem.#{name}.available", fs[:available])
        statsd.gauge("#{key_base}.filesystem.#{name}.used", fs[:used])
        statsd.gauge("#{key_base}.filesystem.#{name}.total", fs[:total])
      end
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    # @return [Hash]
    def calculate_memory
      memory = {}
      return memory unless File.exist?('/proc/meminfo')
      File.open('/proc/meminfo').each do |line|
        case line
        when /^MemTotal:\s+(\d+) (.+)$/
          memory[:total] = $1.to_i * 1024
        when /^MemFree:\s+(\d+) (.+)$/
          memory[:free] = $1.to_i * 1024
        when /^Active:\s+(\d+) (.+)$/
          memory[:active] = $1.to_i * 1024
        when /^Inactive:\s+(\d+) (.+)$/
          memory[:inactive] = $1.to_i * 1024
        when /^Cached:\s+(\d+) (.+)$/
          memory[:cached] = $1.to_i * 1024
        when /^Buffers:\s+(\d+) (.+)$/
          memory[:buffers] = $1.to_i * 1024
        end
      end
      memory[:used] = memory[:total] - memory[:free]

      memory
    end

    # @return [Hash]
    def docker_info
      @docker_info ||= Docker.info
    end
  end
end
