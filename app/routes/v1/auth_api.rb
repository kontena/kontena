require_relative '../../services/auth_service/client'

module V1
  class AuthApi < Roda
    include RequestHelpers

    plugin :json
    plugin :render, engine: 'jbuilder', ext: 'json.jbuilder', views: 'app/views/v1'

    route do |r|
      r.post do
        data = parse_json_body
        begin
          user = AuthService::Client.new.authenticate(data)
        rescue AuthService::Client::Error => e
          halt_request(e.code, JSON.dump(e.message)) and return
        end
        @access_token = AccessTokens::Create.run(
            user: user,
            scopes: data['scope'].to_s.split(',')
        ).result
        if @access_token.nil?
          response.status = 400
          { error: 'Invalid username or password' }
        else
          response.status = 201
          render('auth/show')
        end
      end
    end
  end
end
