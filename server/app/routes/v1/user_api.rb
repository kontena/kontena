
module V1
  class UserApi < Roda
    include OAuth2TokenVerifier
    include CurrentUser
    include RequestHelpers

    plugin :multi_route

    Dir[File.join(__dir__, '/user/*.rb')].each{|f| require f}

    # Route: /v1/user
    route do |r|

      # Route /v1/user/email_confirm
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

      # Route /v1/user/password_reset
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

      # Route /v1/user
      r.get do
        r.is do
          @user = self.current_access_token.user
          render('users/show')
        end
      end
    end
  end
end
