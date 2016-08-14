module V1
  class AuthProviderAPI < Roda
    include RequestHelpers
    include TokenAuthenticationHelper

    route do |r|
      r.get do
        @auth_provider = AuthProvider.instance
        render('auth_provider/show')
      end

      r.post do
        @auth_provider = AuthProvider.instance

        validate_access_token('master_admin') unless current_user_admin?

        params = parse_json_body

        @auth_provider.to_h.each do |key, value|
          @auth_provider[key] = params[key]
        end

        if params['server_name']
          config[:server_name] = params['server_name']
        end

        if @auth_provider.save
          response.status = 201
          render('auth_provider/show')
        else
          response.status = 400
          {'error': 'save failed'}
        end
      end
    end
  end
end

