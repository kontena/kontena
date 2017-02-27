require_relative 'rpc/docker_container_api'
require_relative 'rpc/agent_api'
require_relative 'rpc/etcd_api'
require_relative 'rpc/service_pods_api'
require_relative 'logging'

module Kontena
  class RpcServer
    include Celluloid
    include Kontena::Logging

    HANDLERS = {
        'containers' => Kontena::Rpc::DockerContainerApi,
        'service_pods' => Kontena::Rpc::ServicePodsApi,
        'agent' => Kontena::Rpc::AgentApi,
        'etcd' => Kontena::Rpc::EtcdApi
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
    def handle_request(ws_client, message)
      msg_id = message[1]
      handler = message[2].split('/')[1]
      method = message[2].split('/')[2]
      if klass = HANDLERS[handler]
        begin
          debug "rpc request: #{klass.name}##{method} #{message[3]}"
          result = klass.new.send(method, *message[3])
          send_message(ws_client, [1, msg_id, nil, result])
        rescue RpcServer::Error => exc
          send_message(ws_client, [1, msg_id, {code: exc.code, message: exc.message, backtrace: exc.backtrace}, nil])
        rescue => exc
          error "#{exc.class.name}: #{exc.message}"
          error exc.backtrace.join("\n")
          send_message(ws_client, [1, msg_id, {code: 500, message: "#{exc.class.name}: #{exc.message}", backtrace: exc.backtrace}, nil])
        end
      else
        send_message(ws_client, [1, msg_id, {code: 501, error: 'service not implemented'}, nil])
      end
    end

    # @param [WebsocketClient] ws_client
    # @param [Array, Hash] msg
    def send_message(ws_client, msg)
      ws_client.send_message(MessagePack.dump(msg).bytes)
    end

    ##
    # @param [Array] message msgpack-rpc notification array
    def handle_notification(message)
      handler = message[1].split('/')[1]
      method = message[1].split('/')[2]
      if klass = HANDLERS[handler]
        begin
          debug "rpc notification: #{klass.name}##{method} #{message[2]}"
          klass.new.send(method, *message[2])
        rescue => exc
          error "#{exc.class.name}: #{exc.message}"
          error exc.backtrace.join("\n")
        end
      end
    end
  end
end
