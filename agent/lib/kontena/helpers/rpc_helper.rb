module Kontena
  module Helpers
    module RpcHelper

      # @return [Kontena::RpcClientSession]
      def rpc_client
        @rpc_client ||= Celluloid::Actor[:rpc_client].session
      end
    end
  end
end
