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

      def require_user(user_id)
        @user = User.find_by(external_id: user_id)
        raise RpcServer::Error.new(403, 'Forbidden') unless @user
      end


      def get(user_id, path, options)
        require_user(user_id)
        opts = {
          method: :get,
          params: options
        }
        request(path, opts)
      end

      def post(user_id, path, options)
        require_user(user_id)
        opts = {
          method: :post,
          params: options
        }
        request(path, opts)
      end

      def delete(user_id, path, options)
        require_user(user_id)
        opts = {
          method: :delete
        }
        request(path, opts)
      end

      def put(user_id, path, options)
        require_user(user_id)
        opts = {
          method: :put,
          params: options
        }
        request(path, opts)
      end

      def request(path, opts = {})
        env = Rack::MockRequest.env_for(path, opts)
        env['HTTP_CONTENT_TYPE'] = "application/json"
        env['HTTP_AUTHORIZATION'] = "Bearer #{access_token}"
        status, headers, body = ::Server.call(env)
        result = {
          status: status,
          headers: headers,
          body: body.join
        }

        unless [200, 201].include?(status)
          raise RpcServer::Error.new(status, result)
        end
        result
      ensure
        @access_token.destroy
      end
    end
  end
end
