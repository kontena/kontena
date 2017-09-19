module Kontena::Workers
  class StatsWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Observer::Helper
    include Kontena::Helpers::RpcHelper
    include Kontena::Helpers::StatsHelper
    include Kontena::Helpers::WaitHelper

    PUBLISH_INTERVAL = 60

    attr_reader :statsd

    # @param [Boolean] autostart
    def initialize(autostart = true)
      @node = nil
      @statsd = nil
      info 'initialized'
      async.start if autostart
    end

    def start
      every(PUBLISH_INTERVAL) do
        self.publish_stats
      end

      observe(Actor[:node_info_worker].observable) do |node|
        configure_statsd(node)
      end
    end

    # @param [Node] node
    def configure_statsd(node)
      @node = node
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
    rescue => error
      warn "statsd configuration failed: #{error.message}"
      warn error.backtrace.join("\n") if error.backtrace
    end

    # @return [Boolean]
    def cadvisor_running?
      cadvisor = Docker::Container.get('kontena-cadvisor') rescue nil
      return false if cadvisor.nil?
      cadvisor.info['State']['Running'] == true
    end

    def publish_stats
      wait_until('cadvisor running') { cadvisor_running? }

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

      raw_cpu_usage = current_stat.dig(:cpu, :usage, :total) - prev_stat.dig(:cpu, :usage, :total)
      interval_in_ns = get_interval(current_stat.dig(:timestamp), prev_stat.dig(:timestamp))
      network_traffic = calculate_network_traffic(prev_stat, current_stat)

      container_spec = container[:spec]
      container_spec.delete(:labels) if container_spec.is_a?(Hash) && container_spec.has_key?(:labels)
      data = {
        id: id,
        spec: container_spec,
        cpu: {
          usage: raw_cpu_usage,
          usage_pct: ((raw_cpu_usage / interval_in_ns) * 100).round(2)
        },
        memory: {
          usage: current_stat.dig(:memory, :usage),
          working_set: current_stat.dig(:memory, :working_set)
        },
        filesystem: current_stat[:filesystem],
        diskio: current_stat[:diskio],
        network: network_traffic,
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
      statsd.gauge("#{key_base}.network.internal.rx_bytes", event[:network][:internal][:rx_bytes])
      statsd.gauge("#{key_base}.network.internal.tx_bytes", event[:network][:internal][:tx_bytes])
      statsd.gauge("#{key_base}.network.external.rx_bytes", event[:network][:external][:rx_bytes])
      statsd.gauge("#{key_base}.network.external.tx_bytes", event[:network][:external][:tx_bytes])
    rescue => exc
      error "#{exc.class.name}: #{exc.message}"
      error exc.backtrace.join("\n")
    end

    def calculate_network_traffic(prev_stat, current_stat)
      prev_interfaces = prev_stat.dig(:network, :interfaces)
      current_interfaces = current_stat.dig(:network, :interfaces)

      results = {
        internal: {
          interfaces: [],
          rx_bytes: 0,
          rx_bytes_per_second: 0,
          tx_bytes: 0,
          tx_bytes_per_second: 0
        },
        external: {
          interfaces: [],
          rx_bytes: 0,
          rx_bytes_per_second: 0,
          tx_bytes: 0,
          tx_bytes_per_second: 0
        }
      }

      return results unless prev_interfaces and current_interfaces

      prev_timestamp = Time.parse(prev_stat[:timestamp])
      current_timestamp = Time.parse(current_stat[:timestamp])
      interval_seconds = current_timestamp - prev_timestamp

      internal_interfaces = current_interfaces.select { |iface|
        iface[:name].to_s == "ethwe"
      }

      external_interfaces = current_interfaces.select { |iface|
        iface[:name].to_s == "eth0"
      }

      results[:internal] = calculate_interface_traffic(prev_interfaces, internal_interfaces, interval_seconds)
      results[:external] = calculate_interface_traffic(prev_interfaces, external_interfaces, interval_seconds)

      results
    end
  end
end
