require_relative 'logging'

module Kontena
  class StatsWorker
    include Kontena::Logging

    CADVISOR_URL = 'http://cadvisor:8080/api/v1.2/docker/'
    LOG_NAME = 'StatsWorker'

    attr_reader :url, :queue

    ##
    # @param [String] url cadvisor stats url
    # @param [Queue] queue
    def initialize(url, queue)
      @url = url
      @queue = queue
      logger.info(LOG_NAME) { 'initialized' }
    end

    def start!
      Thread.new {
        loop do
          sleep 10
          logger.debug(LOG_NAME) { 'fetching stats' }
          begin
            data = fetch_stats
            if data
              data.values.each do |container|
                self.send_container_stats(container)
              end
            end
          rescue => exc
            logger.error(LOG_NAME) { "error on stats fetching: #{exc.message}"}
          end
        end
      }
    end

    ##
    # @param [Hash] container
    def send_container_stats(container)
      prev_stat = container['stats'][-2]
      return if prev_stat.nil?

      current_stat = container['stats'][-1]

      num_cores = current_stat['cpu']['usage']['per_cpu_usage'].count
      raw_cpu_usage = current_stat['cpu']['usage']['total'] - prev_stat['cpu']['usage']['total']
      interval_in_ns = get_interval(current_stat['timestamp'], prev_stat['timestamp'])

      event = {
        event: 'container:stats',
        data: {
          id: container['name'].sub('/docker/', ''),
          spec: container['spec'],
          cpu: {
            usage: raw_cpu_usage,
            usage_pct: (((raw_cpu_usage / interval_in_ns ) / num_cores ) * 100).round(2)
          },
          memory: {
            usage: current_stat['memory']['usage'],
            working_set: current_stat['memory']['working_set']
          },
          filesystem: current_stat['filesystem'],
          diskio: current_stat['diskio'],
          network: current_stat['network']
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
        JSON.parse(resp.body) rescue nil
      end
    rescue => exc
      logger.error(LOG_NAME) { "failed to fetch cadvisor stats: #{exc.message}" }
      nil
    end

    def client
      @client ||= Excon.new(self.url)
    end

    def get_interval(current, previous)
      cur  = Time.parse(current).to_f
      prev = Time.parse(previous).to_f

      # to nano seconds
      (cur - prev) * 1000000000
    end
  end
end
