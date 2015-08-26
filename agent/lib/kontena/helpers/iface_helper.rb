require 'socket'
require 'ipaddr'

module Kontena
  module Helpers
    module IfaceHelper

      SIOCGIFADDR = 0x8915

      # @param [String] iface
      # @return [String, NilClass]
      def interface_ip(iface)
        sock = UDPSocket.new
        buf = [iface,""].pack('a16h16')
        sock.ioctl(SIOCGIFADDR, buf);
        sock.close
        buf[20..24].unpack("CCCC").join(".")
      rescue Errno::ENODEV
        nil
      end
    end
  end
end
