require_relative '../../mutations/users/invite'

module V1
  class UsersApi < Roda
    include RequestHelpers
    include CurrentUser
    include TokenAuthenticationHelper

    plugin :multi_route

    Dir[File.join(__dir__, '/users/*.rb')].each{|f| require f}

    route do |r|
      r.on ':username' do |username|
        validate_access_token
        require_current_user
        @user = User.find_by(email: username)

        unless @user
          halt_request(404, {error: 'Not found'})
        end

        r.on 'roles' do
          r.route 'user_roles'
        end

        r.is do
          r.delete do
            outcome = Users::Remove.run(user: @user, current_user: current_user)
            if outcome.success?
              response.status = 200
              {}
            else
              response.status = 400
              {error: outcome.errors.message}
            end
          end
        end
      end

      r.is do
        validate_access_token
        require_current_user

        r.get do
          if !current_user.can_read?(User)
            response.status = 403
            {error: 'Operation not allowed'}
          else
            response.status = 200
            @users = User.all
            render('users/index')
          end
        end
      end
    end
  end
end
