require_relative '../../services/auth_service/client'

module V1
  class AuthApi < Roda
    include RequestHelpers

    route do |r|
      r.post do
        data = parse_json_body
        ENV["AUTH_DEBUG"] && puts("Auth request body: #{data.inspect}")
        begin
          result = AuthService::Client.new.authenticate(data)
          ENV["AUTH_DEBUG"] && puts("Auth service response: #{result.inspect}")
          if result.nil? || result['user'].nil?
            halt_request(403, 'Authentication service response error') and return
          end

          email       = result['user']['username']
          external_id = result['user']['id']
          if email.nil? || external_id.nil?
            halt_request(403, 'Authentication service response error') and return
          end

          if User.count == 0
            user = User.create(email: email, external_id: external_id)
            user.roles << Role.master_admin
          else
            user = User.where(external_id: external_id).first
          end
          if user.nil?
            halt_request(403, 'Forbidden') and return
          end
        rescue AuthService::Client::Error => e
          msg = JSON.parse(e.message) rescue nil
          msg = e.message if msg.nil?
          halt_request(e.code, msg) and return
        end
        @access_token = AccessTokens::Create.run(
            user: user,
            scopes: data['scope'].to_s.split(','),
            access_token: result['access_token'],
            expires_in: result['expires_in']
        ).result
        ENV["AUTH_DEBUG"] && puts("Access token creation result: #{@access_token.inspect}")
        if @access_token.nil?
          halt_request(401, 'Invalid username or password') and return
        else
          response.status = 201
          @access_token.refresh_token = result['refresh_token']
          render('auth/show')
        end
      end
    end
  end
end
