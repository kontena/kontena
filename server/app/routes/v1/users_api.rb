require_relative '../../mutations/users/invite'

module V1
  class UsersApi < Roda
    include RequestHelpers
    include CurrentUser
    include OAuth2TokenVerifier

    plugin :multi_route

    Dir[File.join(__dir__, '/users/*.rb')].each{|f| require f}

    route do |r|
      r.on ':username/roles' do |username|
        @user = User.find_by(email: username)
        r.route 'user_roles'
      end

      r.is do
        r.get do
          validate_access_token
          require_current_user
          if !current_user.can_read?(User)
            response.status = 403
            {error: 'Operation not allowed'}
          else
            response.status = 200
            @users = User.all
            render('users/index')
          end
        end

        r.post do
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
      end
    end
  end
end
