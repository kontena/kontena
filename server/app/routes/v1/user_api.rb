
module V1
  class UserApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers

    plugin :multi_route

    Dir[File.join(__dir__, '/user/*.rb')].each{|f| require f}

    route do |r|

      r.on 'email_confirm' do
        r.post do
          data = parse_json_body
          begin
            AuthService::Client.new.confirm_account(data)
          rescue AuthService::Client::Error => e
            halt_request(e.code, {error: e.message}) and return
          end
          response.status = 200
          {}
        end
      end

      r.on 'password_reset' do
        r.post do
          data = parse_json_body
          begin
            AuthService::Client.new.request_password_reset(data)
          rescue AuthService::Client::Error => e
            halt_request(e.code, {error: e.message}) and return
          end
          response.status = 200
          {}
        end

        r.is method: :put do
          data = parse_json_body
          begin
            AuthService::Client.new.reset_password(data)
          rescue AuthService::Client::Error => e
            halt_request(e.code, {error: e.message}) and return
          end
          response.status = 200
          {}
        end
      end

      validate_access_token
      require_current_user

      # /v1/user/registries
      r.on 'registries' do
        r.route 'registries'
      end

      r.get do
        r.is do
          @user = self.current_access_token.user
          render('users/show')
        end
      end
    end
  end
end
