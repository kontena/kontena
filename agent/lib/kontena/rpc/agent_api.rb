require_relative '../models/node'

module Kontena
  module Rpc
    class AgentApi

      # @param [Hash] data
      def master_info(data)
        Celluloid::Notifications.publish('websocket:connected', {master: data})
        update_version(data['version']) if data['version']
        {}
      end

      # @param [Hash] data
      def node_info(data)
        node = Node.new(data)
        Celluloid::Notifications.publish('agent:node_info', node)
        {}
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
