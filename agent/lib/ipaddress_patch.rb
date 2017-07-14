require 'ipaddress'

class IPAddress::IPv4
  # Return host address within subnet, without prefix mask.
  #
  # @param i [Integer] index within subnet
  # @return [IPAddress::IPv4]
  def host_at(i)
    self.class.parse_u32(self.network_u32 + i)
  end
end
