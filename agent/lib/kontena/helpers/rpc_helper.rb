module Kontena
  module Helpers
    module RpcHelper

      # @return [Kontena::RpcClient]
      def rpc_client
        Kontena::RpcClient.factory
      end
    end
  end
end
