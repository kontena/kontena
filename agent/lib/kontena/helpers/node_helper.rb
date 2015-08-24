require 'socket'
require 'ipaddr'

module Kontena
  module Helpers
    module NodeHelper

      SIOCGIFADDR = 0x8915

      def node_info
        response = Excon.get("#{master_url}/v1/nodes/#{node_id}", headers: {
          'Content-Type' => 'application/json',
          'Kontena-Grid-Token' => ENV['KONTENA_TOKEN']
        })
        if response.status == 200
          return JSON.load(response.body)
        end
        nil
      end

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

      def master_url
        ENV['KONTENA_URI'].sub('ws', 'http')
      end

      def node_id
        Docker.info['ID']
      end

    end
  end
end
