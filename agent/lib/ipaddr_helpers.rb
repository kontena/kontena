class IPAddr
  # @return [Number] CIDR prefix length suffix
  def prefixlen
    @mask_addr.to_s(2).count('1')
  end

  # @return [String] The address + netmask in W.X.Y.Z/P format
  #
  # For a host address, this will include the /32 suffix
  def to_cidr
    "#{to_s}/#{prefixlen}"
  end

  def hostmask
    case @family
    when Socket::AF_INET
      (IN4MASK ^ @mask_addr)
    when Socket::AF_INET6
      (IN6MASK ^ @mask_addr)
    else
      raise AddressFamilyError, "unsupported address family"
    end
  end

  # @return [IPAddr) last address in subnet]
  def last
    self | hostmask
  end

  # @return [IPAddr] ith address in subnet
  def [](i)
    raise ArgumentError, "IP #{i} outside of subnet #{inspect}" if i > hostmask

    self | i
  end

  # Split subnet into lower and upper subnets
  # @return [IPAddr, IPAddr] two sub-subnets
  def split
    high_bit = hostmask + 1 >> 1
    splitlen = prefixlen + 1

    return [
      mask(splitlen),
      mask(splitlen) | high_bit,
    ]
  end
end
