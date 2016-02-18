module Kontena::Workers
  class StatsWorker
    include Celluloid
    include Kontena::Logging

    attr_reader :url, :queue

    ##
    # @param [Queue] queue
    def initialize(queue)
      @queue = queue
      info 'initialized'
      async.start
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
    end

    ##
    # Fetch stats from cAdvisor
    #
    def fetch_stats
      resp = client.get
      if resp.status == 200
        JSON.parse(resp.body, symbolize_names: true) rescue nil
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
  end
end
