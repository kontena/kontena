require_relative 'logging'
require_relative 'rpc_client_session'

module Kontena
  class RpcClient
    include Celluloid
    include Kontena::Logging

    def initialize(ws_client)
      @ws_client = ws_client
      @requests = {}
    end

    # @return [Kontena::RpcClient]
    def session
      RpcClientSession.new(@ws_client, current_actor)
    end

    # @param [Array] response
    def handle_response(response)
      _, msgid, error, result = response
      if session = @requests[msgid]
        begin
          session.handle_response(result, error)
        ensure
          free_id(msgid)
        end
      end
    rescue => exc
      error exc.message
    end

    # @param [RpcClientSession] session
    # @return [Fixnum]
    def request_id(session)
      id = -1
      until id != -1 && !@requests[id]
        id = rand(2_147_483_647)
      end
      @requests[id] = session
      id
    end

    # @param [Integer] id
    # @return [RpcClientSession, NilClass]
    def free_id(id)
      @requests.delete(id)
    end
  end
end
