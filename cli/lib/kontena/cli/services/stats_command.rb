require_relative 'services_helper'

module Kontena::Cli::Services
  class StatsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    MEM_MAX_LIMITS = [
      1.8446744073709552e+19, 9.223372036854772e+18
    ]

    parameter "SERVICE_NAME", "Service name", attribute_name: :name
    option ["-t", "--tail"], :flag, "Tail (follow) stats in real time", default: false

    def execute
      require_api_url
      token = require_token
      if tail?
        system('clear')
        render_header
      end
      loop do
        fetch_stats(token, name, tail?)
        break unless tail?
        sleep(2)
      end
    end

    private

    def fetch_stats(token, service_id, follow)
      result = client(token).get("services/#{parse_service_id(service_id)}/stats")
      system('clear') if follow
      render_header
      result['stats'].each do |stat|
        render_stat_row(stat)
      end
    end

    def render_header
      puts '%-30.30s %-15s %-20s %-15s %-15s' % ['INSTANCE', 'CPU %', 'MEM USAGE/LIMIT', 'MEM %', 'NET I/O']
    end

    def render_stat_row(stat)
      memory = stat['memory'].nil? ? 'N/A' : filesize_to_human(stat['memory']['usage'])
      if !stat['memory'].nil? && (stat['memory']['limit'] && !MEM_MAX_LIMITS.include?(stat['memory']['limit']))
        memory_limit = filesize_to_human(stat['memory']['limit'])
        memory_pct = "#{(stat['memory']['usage'].to_f / stat['memory']['limit'].to_f * 100).round(2)}%"
      else
        memory_limit = 'N/A'
        memory_pct = 'N/A'
      end

      cpu = stat['cpu'].nil? ? 'N/A' : stat['cpu']['usage']

      network_in = stat['network'].nil? ? 'N/A' : filesize_to_human(network_bytes(stat['network'], 'rx_bytes'))
      network_out = stat['network'].nil? ? 'N/A' : filesize_to_human(network_bytes(stat['network'], 'tx_bytes'))

      prefix = self.name.split('/')[0]
      instance_name = stat['container_id'].gsub("#{prefix}-", "")
      puts '%-30.30s %-15s %-20s %-15s %-15s' % [ instance_name, "#{cpu}%", "#{memory} / #{memory_limit}", "#{memory_pct}", "#{network_in}/#{network_out}"]
    end

    ##
    # @param [Integer] size
    # @return [String]
    def filesize_to_human(size)
      return '0B' if size.to_f == 0.0
      units = %w{B K M G T}
      e = (Math.log(size) / Math.log(1000)).floor
      s = '%.2f' % (size.to_f / 1000**e)
      s.sub(/\.?0*$/, units[e])
    rescue FloatDomainError
      'N/A'
    end

    ##
    # @param [Hash] network
    # @param [String] key
    # @return [Integer]
    def network_bytes(network, key)
      (network.dig('internal', key) || 0) + (network.dig('external', key) || 0)
    end
  end
end
