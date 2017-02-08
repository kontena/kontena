require 'socket'
require 'ipaddr'

module Kontena
  module Helpers
    module IfaceHelper

      SIOCGIFADDR = 0x8915

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        # @param [String] iface
        # @return [String, NilClass]
        def interface_ip(iface)
          sock = UDPSocket.new
          buf = [iface,""].pack('a16h16')
          sock.ioctl(SIOCGIFADDR, buf);
          sock.close
          buf[20..24].unpack("CCCC").join(".")
        rescue Errno::EADDRNOTAVAIL
          # interface is up, but does not have any address configured
          nil
        rescue Errno::ENODEV
          nil
        end
      end

      # @param [String] iface
      # @return [String, NilClass]
      def interface_ip(iface)
        self.class.interface_ip(iface)
      end
    end
  end
end
