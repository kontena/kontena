require_relative 'rpc/docker_container_api'
require_relative 'rpc/docker_image_api'
require_relative 'rpc/agent_api'
require_relative 'logging'

module Kontena
  class RpcServer
    LOG_NAME = 'RpcServer'

    HANDLERS = {
        'containers' => Kontena::Rpc::DockerContainerApi,
        'images' => Kontena::Rpc::DockerImageApi,
        'agent' => Kontena::Rpc::AgentApi
    }

    class Error < StandardError
      attr_accessor :code, :message, :backtrace

      def initialize(code, message, backtrace = nil)
        self.code = code
        self.message = message
        self.backtrace = backtrace
      end
    end

    ##
    # @param [Array] message msgpack-rpc request array
    # @return [Array]
    def self.handle_request(message)
      msg_id = message[1]
      handler = message[2].split('/')[1]
      method = message[2].split('/')[2]
      if klass = HANDLERS[handler]
        begin
          Kontena::Logging.logger.info(LOG_NAME) { "rpc request: #{klass.name}##{method} #{message[3]}" }
          result = klass.new.send(method, *message[3])
          return [1, msg_id, nil, result]
        rescue RpcServer::Error => exc
          return [1, msg_id, {code: exc.code, message: exc.message, backtrace: exc.backtrace}, nil]
        rescue => exc
          Kontena::Logging.logger.error(LOG_NAME) { "#{exc.class.name}: #{exc.message}" }
          Kontena::Logging.logger.error(LOG_NAME) { exc.backtrace.join("\n") }
          return [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}", backtrace: exc.backtrace}, nil]
        end
      else
        return [1, msg_id, {error: 'service not implemented'}, nil]
      end
    end
  end
end
