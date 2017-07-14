require 'ipaddress'

class Node

  attr_reader :id,
              :created_at,
              :updated_at,
              :name,
              :labels,
              :peer_ips,
              :node_number,
              :initial_member,
              :grid

  # @param [Hash] data
  def initialize(data)
    @id = data['id']
    @created_at = data['created_at']
    @updated_at = data['updated_at']
    @name = data['name']
    @labels = data['labels']
    @overlay_ip = data['overlay_ip']
    @peer_ips = data['peer_ips']
    @node_number = data['node_number']
    @initial_member = data['initial_member']
    @grid = data['grid']
  end

  def statsd_conf
    grid.dig('stats', 'statsd') || {}
  end

  # @return [IPAddress] 10.81.0.0/16
  def grid_subnet
    IPAddress.parse(@grid['subnet'])
  end

  # @return [Array<String>] 192.168.66.0/24
  def grid_trusted_subnets
    @grid['trusted_subnets']
  end

  # @return [IPAddress] 10.81.0.X
  def overlay_ip
    IPAddress.parse(@overlay_ip)
  end

  # @return [String]
  def overlay_cidr
    "#{overlay_ip}/#{grid_subnet.prefix}"
  end
end
