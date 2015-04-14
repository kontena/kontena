module Kontena
  module Rpc
    class AgentApi

      ##
      # @param [String] ip
      # @param [String] port
      # @return [Hash]
      def port_open?(ip, port)
        Timeout::timeout(2) do
          begin
            TCPSocket.new(ip, port).close
            {open: true}
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
            {open: false}
          end
        end
      rescue Timeout::Error
        {open: false}
      end
    end
  end
end