module Rpc
  class DnsApi

    attr_reader :grid

    ##
    # @param [Grid] grid
    def initialize(grid)
      @grid = grid
    end

    ##
    # @param [String] name
    # @return [Array]
    def record(name)
      container = grid.containers.find_by(name: name)
      if container && container.network_settings['ip_address']
        return [container.network_settings['ip_address']]
      end
      service = grid.grid_services.find_by(name: name)
      if service
        return service.containers.select{|c| c.network_settings['ip_address'] }.map{|c| c.network_settings['ip_address'] }
      end

      []
    end
  end
end