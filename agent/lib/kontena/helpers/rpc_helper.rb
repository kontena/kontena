module Kontena
  module Helpers
    module RpcHelper

      # @return [Kontena::RpcClient]
      def rpc_client
        Celluloid::Actor[:rpc_client]
      end
    end
  end
end
