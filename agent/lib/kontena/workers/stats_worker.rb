require 'vmstat'

module Kontena::Workers
  class StatsWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::NodeHelper

    attr_reader :statsd, :node_name

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @statsd = nil
      @node_name = nil
      @container_seconds = 0

      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      subscribe('container:event', :on_container_event)
      async.start if autostart
    end

    # @param [String] topic
    # @param [Node] node
    def on_node_info(topic, node)
      @node_name = node.name
      if @node.nil? || (@node.statsd_conf != node.statsd_conf)
        configure_statsd(node)
      end
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

    # @param [Hash] node
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

    def start
      info 'waiting for cadvisor'
      sleep 1 until cadvisor_running?
      info 'cadvisor is running, starting stats loop'

      every(60) do
        publish_node_stats
      end

      last_collected = Time.now.to_i
      loop do
        sleep 1 until last_collected < (Time.now.to_i - 60)
        self.collect_container_stats
        last_collected = Time.now.to_i
      end
    end

    def collect_container_stats
      debug 'starting collection'

      if response = get("/api/v1.2/subcontainers")
        response.each do |data|
          next unless data[:namespace] == 'docker'

          # Skip systemd mount units that confuse cadvisor
          # @see https://github.com/kontena/kontena/issues/1656
          next if data[:name].end_with? '.mount'

          send_container_stats(data)
        end
      end

    rescue => exc
      error "error on stats fetching: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    def get(path)
      retries = 3
      begin
        response = client.get(:path => path)
        if response.status == 200
          JSON.parse(response.body, symbolize_names: true) rescue nil
        else
          error "failed to fetch cadvisor stats: #{response.status} #{response.body}"
          nil
        end
      rescue => exc
        retries -= 1
        if retries > 0
          retry
        end
        error "get #{path}: #{exc.class.name}: #{exc.message}"
        nil
      end
    end

    # @param [Hash] container
    def send_container_stats(container)
      id = container[:id]
      name = container[:aliases].select{|a| a != id}.first

      prev_stat = container.dig(:stats)[-2] if container
      return if prev_stat.nil?

      current_stat = container.dig(:stats, -1)
      # Need to default to something usable in calculations

      cpu_usages = current_stat.dig(:cpu, :usage, :per_cpu_usage)
      num_cores = cpu_usages ? cpu_usages.count : 1
      raw_cpu_usage = current_stat.dig(:cpu, :usage, :total) - prev_stat.dig(:cpu, :usage, :total)
      interval_in_ns = get_interval(current_stat.dig(:timestamp), prev_stat.dig(:timestamp))

      data = {
        id: id,
        spec: container.dig(:spec),
        cpu: {
          usage: raw_cpu_usage,
          usage_pct: (((raw_cpu_usage / interval_in_ns ) / num_cores ) * 100).round(2)
        },
        memory: {
          usage: current_stat.dig(:memory, :usage),
          working_set: current_stat.dig(:memory, :working_set)
        },
        filesystem: current_stat[:filesystem],
        diskio: current_stat[:diskio],
        network: current_stat[:network],
        time: Time.now.utc.to_s
      }
      rpc_client.async.notification('/containers/stat', [data])
      send_container_statsd_metrics(name, data)
    end

    def client
      if @client.nil?
        @client = Excon.new("http://127.0.0.1:8989/api/v1.2/docker/")
      end
      @client
    end

    # @param [String] current
    # @param [String] previous
    def get_interval(current, previous)
      cur  = Time.parse(current).to_f
      prev = Time.parse(previous).to_f

      # to nano seconds
      (cur - prev) * 1000000000
    end

    # @return [Boolean]
    def cadvisor_running?
      cadvisor = Docker::Container.get('kontena-cadvisor') rescue nil
      return false if cadvisor.nil?
      cadvisor.info['State']['Running'] == true
    end

    # @param [String] name
    # @param [Hash] event
    def send_container_statsd_metrics(name, event)
      return unless statsd
      labels = event[:spec][:labels]
      if labels && labels[:'io.kontena.service.name']
        key_base = "services.#{name}"
      else
        key_base = "#{node_name}.containers.#{name}"
      end
      statsd.gauge("#{key_base}.cpu.usage", event[:cpu][:usage_pct])
      statsd.gauge("#{key_base}.memory.usage", event[:memory][:usage])
      interfaces = event.dig(:network, :interfaces) || []
      interfaces.each do |iface|
        [:rx_bytes, :tx_bytes].each do |metric|
          statsd.gauge("#{key_base}.network.iface.#{iface[:name]}.#{metric}", iface[metric])
        end
      end
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    def publish_node_stats
      disk = Vmstat.disk('/')
      load_avg = Vmstat.load_average

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
        time: Time.now.utc.to_s
      }
      rpc_client.async.notification('/nodes/stats', [data])
      send_node_statsd_metrics(data)
    end

    # @param [Hash] event
    def send_node_statsd_metrics(event)
      return unless statsd
      key_base = "#{docker_info['Name']}"
      statsd.gauge("#{key_base}.cpu.load.1m", event[:load][:'1m'])
      statsd.gauge("#{key_base}.cpu.load.5m", event[:load][:'5m'])
      statsd.gauge("#{key_base}.cpu.load.15m", event[:load][:'15m'])
      statsd.gauge("#{key_base}.memory.active", event[:memory][:active])
      statsd.gauge("#{key_base}.memory.free", event[:memory][:free])
      statsd.gauge("#{key_base}.memory.total", event[:memory][:total])
      statsd.gauge("#{key_base}.usage.container_seconds", event[:usage][:container_seconds])
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
  end
end
