module Kontena::Workers
  class StatsWorker
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging

    attr_reader :queue, :statsd, :node_name

    ##
    # @param [Queue] queue
    # @param [Boolean] autostart
    def initialize(queue, autostart = true)
      @queue = queue
      @statsd = nil
      @node_name = nil
      info 'initialized'
      subscribe('agent:node_info', :on_node_info)
      async.start if autostart
    end

    # @param [String] topic
    # @param [Hash] info
    def on_node_info(topic, info)
      @node_name = info['name']
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
      begin
        data = fetch_stats
        if data
          debug "total stats size: #{data.values.size}"
          data.values.each do |container|
            self.send_container_stats(container)
            sleep 0.5
          end
        end
      rescue => exc
        error "error on stats fetching: #{exc.message}"
      end
    end

    ##
    # @param [Hash] container
    def send_container_stats(container)
      prev_stat = container[:stats][-2]
      return if prev_stat.nil?

      current_stat = container[:stats][-1]

      num_cores = current_stat[:cpu][:usage][:per_cpu_usage].count
      raw_cpu_usage = current_stat[:cpu][:usage][:total] - prev_stat[:cpu][:usage][:total]
      interval_in_ns = get_interval(current_stat[:timestamp], prev_stat[:timestamp])

      event = {
        event: 'container:stats'.freeze,
        data: {
          id: container[:aliases][1],
          spec: container[:spec],
          cpu: {
            usage: raw_cpu_usage,
            usage_pct: (((raw_cpu_usage / interval_in_ns ) / num_cores ) * 100).round(2)
          },
          memory: {
            usage: current_stat[:memory][:usage],
            working_set: current_stat[:memory][:working_set]
          },
          filesystem: current_stat[:filesystem],
          diskio: current_stat[:diskio],
          network: current_stat[:network]
        }
      }

      self.queue << event
      send_statsd_metrics(container[:aliases][0], event[:data])
    end

    ##
    # Fetch stats from cAdvisor
    #
    def fetch_stats
      resp = client.get
      if resp.status == 200
        JSON.parse(resp.body, symbolize_names: true) rescue nil
      else
        error "failed to fetch cadvisor stats: #{resp.status} #{resp.body}"
      end
    rescue => exc
      error "failed to fetch cadvisor stats: #{exc.message}"
      nil
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
  end
end
