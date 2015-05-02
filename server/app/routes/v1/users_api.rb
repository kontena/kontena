require_relative '../../mutations/users/register'
require_relative '../../mutations/users/invite'

module V1
  class UsersApi < Roda
    include RequestHelpers
    include CurrentUser
    include OAuth2TokenVerifier

    route do |r|
      r.post do
        r.is do
          validate_access_token
          require_current_user

          params = parse_json_body
          params[:user] = current_user
          outcome = Users::Invite.run(params)
          if outcome.success?
            response.status = 201
            @user = outcome.result
            render('users/show')
          else
            response.status = 422
            {error: outcome.errors.message}
          end
        end

        r.on 'register' do
          params = parse_json_body
          outcome = Users::Register.run(params)
          if outcome.success?
            response.status = 200
            @user = outcome.result
            render('users/show')
          else
            response.status = 422
            {error: outcome.errors.message}
          end
        end
      end
    end
  end
end
