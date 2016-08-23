
module V1
  class UserApi < Roda
    include TokenAuthenticationHelper
    include CurrentUser
    include RequestHelpers

    plugin :multi_route

    Dir[File.join(__dir__, '/user/*.rb')].each{|f| require f}

    # Route: /v1/user
    route do |r|
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
