require_relative 'rpc/server_api'
module Cloud
  class RpcServer
    include Logging
    HANDLERS = {
      'master' => Cloud::Rpc::ServerApi
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
      handler, method, path = message[2].split('/', 2)
      if klass = HANDLERS[handler]
        info "rpc request: #{klass.name}##{method} #{path} #{message[3]}"
        begin
          result = klass.new.send(method, path, message[3])
          return [1, msg_id, nil, result]
        rescue RpcServer::Error => exc
          return [1, msg_id, {code: exc.code, message: exc.message, backtrace: exc.backtrace}, nil]
        rescue => exc
          puts "#{exc.class.name}: #{exc.message}"
          puts exc.backtrace.join("\n")
          return [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}", backtrace: exc.backtrace}, nil]
        end
      else
        return [1, msg_id, {error: 'service not implemented'}, nil]
      end
    end
  end
end
