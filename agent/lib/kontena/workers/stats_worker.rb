module Kontena::Workers
  class StatsWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer
    include Kontena::Helpers::RpcHelper

    attr_reader :statsd

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @statsd = nil
      info 'initialized'
      async.start if autostart

      observe(node: Actor[:node_info_worker]) do
        configure_statsd(@node)
      end
    end

    # @param [Node] node
    def configure_statsd(node)
      statsd_conf = node.statsd_conf
      debug "configure stats: #{statsd_conf}"
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
      last_collected = Time.now.to_i
      loop do
        sleep 1 until last_collected < (Time.now.to_i - 60)
        self.collect_stats
        last_collected = Time.now.to_i
      end
    end

    def collect_stats
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
      send_statsd_metrics(name, data)
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
    def send_statsd_metrics(name, event)
      return unless statsd
      labels = event[:spec][:labels]
      if labels && labels[:'io.kontena.service.name']
        key_base = "services.#{name}"
      else
        key_base = "#{@node.name}.containers.#{name}"
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
  end
end
