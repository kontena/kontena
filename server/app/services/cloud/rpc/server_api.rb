require 'securerandom'
module Cloud
  module Rpc
    class ServerApi
      def access_token
        token = SecureRandom.hex(32)
        @access_token = AccessToken.create!(
          token_type: 'bearer',
          expires_at: Time.now.utc + 60,
          scopes: ['owner'],
          internal: true,
          user: @user,
          token_plain: token
        )
        token
      end

      def require_user(data)
        external_user_id = data['user_id']
        raise RpcServer::Error.new(403, 'Forbidden') unless external_user_id
        @user = User.find_by(external_id: external_user_id)
        raise RpcServer::Error.new(403, 'Forbidden') unless @user
      end


      def get(path, options)
        require_user(options)
        opts = {
          method: :get
        }
        request(path, opts)
      end

      def post(path, options)
        require_user(options)
        opts = {
          method: :post,
          params: options['params']
        }
        request(path, opts)
      end

      def delete(path, options)
        require_user(options)
        opts = {
          method: :delete
        }
        request(path, opts)
      end

      def put(path, options)
        require_user(options)
        opts = {
          method: :put,
          params: options['params']
        }
        request(path, opts)
      end

      def request(path, opts = {})
        env = Rack::MockRequest.env_for(path, opts)
        env['HTTP_CONTENT_TYPE'] = "application/json"
        env['HTTP_AUTHORIZATION'] = "Bearer #{access_token}"
        status, headers, body = ::Server.call(env)
        @access_token.destroy
        result = JSON.parse(body[0]) if body.size > 0
        unless [200, 201].include?(status)
          raise RpcServer::Error.new(status, result)
        end
        result
      end
    end
  end
end
