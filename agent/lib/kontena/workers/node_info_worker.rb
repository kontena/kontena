require 'net/http'
require 'vmstat'

require_relative '../models/node'
require_relative '../helpers/node_helper'
require_relative '../helpers/iface_helper'
require_relative '../helpers/rpc_helper'
require_relative '../helpers/stats_helper'

module Kontena::Workers
  class NodeInfoWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observable
    include Kontena::Helpers::NodeHelper
    include Kontena::Helpers::IfaceHelper
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::StatsHelper

    attr_reader :statsd, :stats_since, :node

    PUBLISH_INTERVAL = 60

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @statsd = nil
      @stats_since = Time.now
      @container_seconds = 0
      @previous_cpu = Vmstat.cpu
      @previous_network = Vmstat.network_interfaces
      subscribe('websocket:connected', :on_websocket_connected)
      subscribe('agent:node_info', :on_node_info)
      subscribe('container:event', :on_container_event)
      info 'initialized'
      async.start if autostart
    end

    # @param [String] topic
    # @param [Hash] data
    def on_websocket_connected(topic, data)
      self.publish_node_info
      self.publish_node_stats
    end

    def start
      loop do
        sleep PUBLISH_INTERVAL
        self.publish_node_info
        self.publish_node_stats
      end
    end

    # @param [String] topic
    # @param [Node] node
    def on_node_info(topic, node)
      if @node.nil? || (@node.statsd_conf != node.statsd_conf)
        configure_statsd(node)
      end
      @node = node
      update_observable(node)
    end

    # @param [Node] node
    def configure_statsd(node)
      statsd_conf = node.statsd_conf
      if statsd_conf && statsd_conf['server']
        info "exporting stats via statsd to udp://#{statsd_conf['server']}:#{statsd_conf['port']}"
        @statsd = Statsd.new(
          statsd_conf['server'], statsd_conf['port'].to_i || 8125
        ).tap{ |sd| sd.namespace = node.grid['name'] }
      else
        @statsd = nil
      end
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
          drivers << { name: plugin['Name'] } if plugin['Enabled']
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
          drivers << { name: plugin['Name'] } if plugin['Enabled']
        end
      end
      docker_info.dig('Plugins', 'Network').to_a.each do |plugin|
        drivers << { name: plugin }
      end

      drivers
    end

    # @return [Array<Hash>]
    def plugins
      JSON.parse(Docker.connection.get('/plugins'))
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

    # @param [String] topic
    # @param [Docker::Event] event
    def on_container_event(topic, event)
      if event.status == 'die'.freeze
        container = Docker::Container.get(event.id) rescue nil
        if container
          @container_seconds += calculate_container_time(container)
        end
      end
    end

    def publish_node_stats
      disk = Vmstat.disk('/')
      load_avg = Vmstat.load_average
      current_cpu = Vmstat.cpu
      cpu_usage = calculate_cpu_usage(@previous_cpu, current_cpu)
      @previous_cpu = current_cpu

      current_network = Vmstat.network_interfaces
      network_traffic = calculate_network_traffic(@previous_network, current_network, Time.now - @stats_since)
      @previous_network = current_network

      container_partial_seconds = @container_seconds.to_i
      @container_seconds = 0
      container_seconds = calculate_containers_time + container_partial_seconds
      @stats_since = Time.now

      data = {
        id: docker_info['ID'],
        memory: calculate_memory,
        usage: {
          container_seconds: container_seconds
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
        ],
        cpu: cpu_usage,
        network: network_traffic,
        time: Time.now.utc.to_s
      }
      rpc_client.async.notification('/nodes/stats', [data])
      send_statsd_metrics(data)
    end

    # @param [Hash] event
    def send_statsd_metrics(event)
      return unless statsd
      key_base = "#{docker_info['Name']}"
      statsd.gauge("#{key_base}.cpu.load.1m", event[:load][:'1m'])
      statsd.gauge("#{key_base}.cpu.load.5m", event[:load][:'5m'])
      statsd.gauge("#{key_base}.cpu.load.15m", event[:load][:'15m'])
      statsd.gauge("#{key_base}.cpu.system", event[:cpu][:system])
      statsd.gauge("#{key_base}.cpu.user", event[:cpu][:user])
      statsd.gauge("#{key_base}.cpu.nice", event[:cpu][:nice])
      statsd.gauge("#{key_base}.cpu.idle", event[:cpu][:idle])
      statsd.gauge("#{key_base}.memory.active", event[:memory][:active])
      statsd.gauge("#{key_base}.memory.free", event[:memory][:free])
      statsd.gauge("#{key_base}.memory.total", event[:memory][:total])
      statsd.gauge("#{key_base}.usage.container_seconds", event[:usage][:container_seconds])
      statsd.gauge("#{key_base}.network.internal.rx_bytes", event[:network][:internal][:rx_bytes])
      statsd.gauge("#{key_base}.network.internal.tx_bytes", event[:network][:internal][:tx_bytes])
      statsd.gauge("#{key_base}.network.external.rx_bytes", event[:network][:external][:rx_bytes])
      statsd.gauge("#{key_base}.network.external.tx_bytes", event[:network][:external][:tx_bytes])
      event[:filesystem].each do |fs|
        name = fs[:name] ? fs[:name].split("/")[1..-1].join(".") : ""
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

    # @param [Time] since
    def calculate_containers_time
      seconds = 0
      Docker::Container.all.each do |container|
        seconds += calculate_container_time(container)
      end

      seconds
    rescue => exc
      error exc.message
    end

    # @param [Docker::Container] container
    # @return [Integer]
    def calculate_container_time(container)
      state = container.state
      since = stats_since.to_time.utc
      started_at = DateTime.parse(state['StartedAt']).to_time.utc rescue nil
      finished_at = DateTime.parse(state['FinishedAt']).to_time.utc rescue nil
      seconds = 0
      return seconds unless started_at
      if state['Running']
        now = Time.now.utc.to_i
        if started_at < since
          # container has started before last check
          seconds = now - since.to_i
        elsif started_at >= since
          # container has started after last check
          seconds = now - started_at.to_time.to_i
        end
      else
        if finished_at && started_at < finished_at && started_at > since
          # container has started before last check
          seconds = finished_at.to_i - started_at.to_i
        elsif finished_at && started_at < finished_at && started_at <= since
          # container has started after last check
          seconds = finished_at.to_i - since.to_i
        end
      end

      seconds
    rescue => exc
      debug exc.message
      0
    end

    # @param [Array<Vmstat::Cpu>] prev_cpus
    # @param [Array<Vmstat::Cpu>] current_cpu
    # @return [Hash] { :num_cores, :system, :user, :idle }
    def calculate_cpu_usage(prev_cpus, current_cpus)
      result = {
        num_cores: prev_cpus.size,
        system: 0.0,
        user: 0.0,
        nice: 0.0,
        idle: 0.0
      }

      prev_cpus.zip(current_cpus).map { |prev_cpu, current_cpu|
        system_ticks = current_cpu.system - prev_cpu.system
        user_ticks = current_cpu.user - prev_cpu.user
        nice_ticks = current_cpu.nice = prev_cpu.nice
        idle_ticks = current_cpu.idle - prev_cpu.idle

        total_ticks = (system_ticks + user_ticks + nice_ticks + idle_ticks).to_f

        {
          system: (system_ticks / total_ticks) * 100.0,
          user: (user_ticks / total_ticks) * 100.0,
          nice: (nice_ticks / total_ticks) * 100.0,
          idle: (idle_ticks / total_ticks) * 100.0
        }
      }.inject(result) { |memo, cpu_core|
        memo[:system] += cpu_core[:system]
        memo[:user] += cpu_core[:user]
        memo[:nice] += cpu_core[:nice]
        memo[:idle] += cpu_core[:idle]
        memo
      }
    end

    # @param [Array<Vmstat::NetworkInterface>] prev_interfaces
    # @param [Array<Vmstat::NetworkInterface>] current_interfaces
    # @param [Number] interval_seconds
    # @return [Hash]
    def calculate_network_traffic(prev_interfaces, current_interfaces, interval_seconds)
      prev_interfaces = prev_interfaces.map { |iface| {
        name: iface.name,
        rx_bytes: iface.in_bytes,
        tx_bytes: iface.out_bytes
      }}

      internal_interfaces = current_interfaces.select { |iface|
        iface.name.to_s == "weave" or iface.name.to_s.start_with?("vethwe")
      }
      .map { |iface| {
          name: iface.name,
          rx_bytes: iface.in_bytes,
          tx_bytes: iface.out_bytes
      }}

      external_interfaces = current_interfaces.select { |iface|
        iface.name.to_s == "docker0"
      }
      .map { |iface| {
          name: iface.name,
          rx_bytes: iface.in_bytes,
          tx_bytes: iface.out_bytes
      }}

      {
        internal: calculate_interface_traffic(prev_interfaces, internal_interfaces, interval_seconds),
        external: calculate_interface_traffic(prev_interfaces, external_interfaces, interval_seconds)
      }
    end

    # @return [Hash]
    def docker_info
      @docker_info ||= Docker.info
    end
  end
end
