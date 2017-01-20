require 'ipaddress'

module Kontena::Models
  # Persistent NodeInfo state, updated via RPC, and shared between multiple actors
  # Frozen for thread-safety
  class NodeInfo
    # @param info [Hash] JSON
    def initialize(info)
      @info = info
      self.freeze
    end

    # @return [String]
    def version
      @info['version']
    end

    # @return [IPAddress] 10.81.0.0/16
    def grid_subnet
      IPAddress.parse(@info['grid']['subnet'])
    end

    # return [Array<String>]
    def grid_trusted_subnets
      @info['grid']['trusted_subnets'] || []
    end

    # @return [String] 10.81.0.X
    def overlay_ip
      @info['overlay_ip']
    end

    # @return [String, nil] 10.81.0.X/16
    def overlay_cidr
      "#{overlay_ip}/#{grid_subnet.prefix}" if grid_subnet && overlay_ip
    end

    # @return [Array<String>]
    def peer_ips
      @info['peer_ips']
    end
  end
end
