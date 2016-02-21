require_relative '../../services/auth_service/client'

module V1
  class AuthApi < Roda
    include RequestHelpers

    route do |r|
      r.post do
        data = parse_json_body
        begin
          result = AuthService::Client.new.authenticate(data)
          if result.nil?
            return nil
          end
          email = result['email']
          if User.count == 0
            user = User.create(email: email)
            user.roles << Role.master_admin
          else
            user = User.find_by(email: email)
          end
          if user.nil?
            halt_request(403, 'Forbidden') and return
          end
          user.update_attribute(:external_id, result['id'])
        rescue AuthService::Client::Error => e
          msg = JSON.parse(e.message) rescue nil
          msg = e.message if msg.nil?
          halt_request(e.code, msg) and return
        end
        @access_token = AccessTokens::Create.run(
            user: user,
            scopes: data['scope'].to_s.split(',')
        ).result
        if @access_token.nil?
          response.status = 401
          { error: 'Invalid username or password' }
        else
          response.status = 201
          render('auth/show')
        end
      end
    end
  end
end
