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
        rpc_client.request(method, params)
      end
    end
  end
end
