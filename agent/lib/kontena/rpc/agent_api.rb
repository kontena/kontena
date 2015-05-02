module Kontena
  module Rpc
    class AgentApi

      ##
      # @param [String] ip
      # @param [String] port
      # @param [Float] timeout
      # @return [Hash]
      def port_open?(ip, port, timeout = 2.0)
        Timeout::timeout(timeout) do
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
