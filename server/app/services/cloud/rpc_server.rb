require_relative 'rpc/server_api'
module Cloud
  class RpcServer
    include Logging
    HANDLERS = {
      'rest_request' => Cloud::Rpc::ServerApi
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
    def handle_request(message)
      msg_id = message[1]
      handler, method = message[2].split('/')
      if klass = HANDLERS[handler]
        debug "rpc request: #{klass.name}##{method} #{message[3]}"
        begin
          result = klass.new.send(method, *message[3])
          return [1, msg_id, nil, result]
        rescue RpcServer::Error => exc
          return [1, msg_id, {code: exc.code, message: exc.message, backtrace: exc.backtrace}, nil]
        rescue => exc
          error "#{exc.class.name}: #{exc.message}"
          error exc.backtrace.join("\n")
          return [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}", backtrace: exc.backtrace}, nil]
        end
      else
        return [1, msg_id, {error: 'service not implemented'}, nil]
      end
    end
  end
end
