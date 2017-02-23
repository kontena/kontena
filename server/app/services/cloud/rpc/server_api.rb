require 'securerandom'
module Cloud
  module Rpc
    class ServerApi
      include Logging
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

      def delete(user_id, path, options=nil)
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

      protected

      def require_user(user_id)
        @user = User.find_by(external_id: user_id)
        raise RpcServer::Error.new(403, 'Invalid user') unless @user
      end

      def request(path, opts = {})
        start_time = Time.now.to_f
        env = Rack::MockRequest.env_for(path, opts)
        env['CONTENT_TYPE'] = "application/json"
        env['HTTP_AUTHORIZATION'] = "Bearer #{access_token}"
        status, headers, body = Server.call(env)
        result = {
          status: status,
          headers: headers,
          body: body.join
        }
        end_time = Time.now.to_f
        info "\"#{opts[:method].to_s.upcase} #{path}\" #{status} #{headers['Content-Length']} #{(end_time-start_time).round(4)}"
        result
      ensure
        @access_token.destroy
      end
    end
  end
end
