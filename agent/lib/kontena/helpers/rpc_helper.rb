module Kontena
  module Helpers
    module RpcHelper

      # @return [Kontena::RpcClient]
      def rpc_client
        Celluloid::Actor[:rpc_client]
      end

      # @param method [String]
      # @param params [Array]
      # @raise [Kontena::RpcClient::Error]
      # @return [Object]
      def rpc_request(method, params)
        response, error = rpc_client.request_with_error(method, params)

        if error
          raise error
        else
          return response
        end
      end
    end
  end
end
