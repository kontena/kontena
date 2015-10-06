module Kontena
  module Rpc
    class AgentApi

      # @param [Hash] data
      def master_info(data)
        Pubsub.publish('websocket:connected', {master: data})
        update_version(data['version']) if data['version']
        {}
      end

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

      private

      # @param [String] version
      def update_version(version)
        env_file = '/etc/kontena.env'
        if File.exist?(env_file)
          env = File.read(env_file)
          env.gsub!(/^KONTENA_VERSION=.+$/, "KONTENA_VERSION=#{version}")
          File.write(env_file, env)
        end
      end
    end
  end
end
