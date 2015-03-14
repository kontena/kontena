require 'kontena/client'
require_relative '../common'
require 'pp'

module Kontena::Cli::Services
  class Stats
    include Kontena::Cli::Common

    def show(service_id)
      require_api_url
      token = require_token

      result = client(token).get("services/#{service_id}/stats")

      rows = [['CONTAINER', 'CPU %', 'MEM USAGE/LIMIT', 'MEM %', 'NET I/O']]
      result['stats'].each do |stat|
        memory = filesize_to_human(stat['memory']['usage'])
        if stat['memory']['limit'] != 1.8446744073709552e+19
          memory_limit = filesize_to_human(stat['memory']['limit'])
          memory_pct = "#{(memory.to_f / memory_limit.to_f * 100).round(2)}%"
        else
          memory_limit = 'N/A'
          memory_pct = 'N/A'
        end
        cpu = stat['cpu']['usage']
        network_in = filesize_to_human(stat['network']['rx_bytes'])
        network_out = filesize_to_human(stat['network']['tx_bytes'])
        rows << [ stat['container_id'], "#{cpu}%", "#{memory}/#{memory_limit}", "#{memory_pct}", "#{network_in}/#{network_out}"]
      end
      table = Terminal::Table.new rows: rows, style: { border_y: '', border_x: '', border_i: '', width: 100 }
      puts table

    end

    private
    ##
    # @param [String] memory
    # @return [Integer]
    def parse_memory(memory)
      if memory.end_with?('k')
        memory.to_i * 1000
      elsif memory.end_with?('m')
        memory.to_i * 1000000
      elsif memory.end_with?('g')
        memory.to_i * 1000000000
      else
        memory.to_i
      end
    end

    ##
    # @param [Integer] size
    # @return [String]
    def filesize_to_human(size)
      units = %w{B K M G T}
      e = (Math.log(size)/Math.log(1000)).floor
      s = '%.2f' % (size.to_f / 1000**e)
      s.sub(/\.?0*$/, units[e])
    end
  end
end