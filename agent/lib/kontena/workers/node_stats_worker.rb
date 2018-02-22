require 'net/http'
require 'vmstat'

require_relative '../models/node'
require_relative '../helpers/rpc_helper'
require_relative '../helpers/stats_helper'

module Kontena::Workers
  class NodeStatsWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::StatsHelper

    attr_reader :node, :statsd, :stats_since

    PUBLISH_INTERVAL = 60

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @node = nil
      @statsd = nil
      @stats_since = Time.now
      @container_seconds = 0
      @previous_cpu = Vmstat.cpu
      @previous_network = Vmstat.network_interfaces
      subscribe('container:event', :on_container_event)
      info 'initialized'
      async.start if autostart
    end

    def start
      every(PUBLISH_INTERVAL) do
        self.publish_node_stats
      end

      observe(Actor[:node_info_worker].observable) do |node|
        configure(node)
      end
    end

    def configure(node)
      unless @node && @node.statsd_conf == node.statsd_conf
        @statsd = self.configure_statsd(node)
      end

      @node = node
    end

    # @param [Node] node
    # @return [Statsd]
    def configure_statsd(node)
      statsd_conf = node.statsd_conf
      if statsd_conf && statsd_conf['server']
        info "exporting stats via statsd to udp://#{statsd_conf['server']}:#{statsd_conf['port']}"

        return Statsd.new(
          statsd_conf['server'], statsd_conf['port'].to_i || 8125
        ).tap{ |sd| sd.namespace = node.grid['name'] }
      else
        return nil
      end
    rescue => exc
      error "failed to configure statsd: #{exc.message}"
      error exc.backtrace.join("\n")
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
      stats = collect_node_stats

      send_node_stats(stats) if @node
      send_statsd_metrics(stats) if @statsd
    end

    # @return [Hash]
    def collect_node_stats
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

      {
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
    end

    # @param [Hash] data
    def send_node_stats(data)
      rpc_client.async.notification('/nodes/stats', [@node.id, data])
    end

    # @param [Hash] event
    def send_statsd_metrics(event)
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
        nice_ticks = current_cpu.nice - prev_cpu.nice
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
