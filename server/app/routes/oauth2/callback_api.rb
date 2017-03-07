module OAuth2Api
  # The /cb endpoint handles authorization callbacks when the browser is
  # returning from auth provider during the auth process.
  #
  # It tries to find a matching AuthorizationRequest by using the state
  # parameter.
  #
  # Normally the auth provider will pass a code in the redirect uri,
  # this authorization code will be exchanged for an access token
  # from the AP's token endpoint.
  #
  # The access token will then be used to request basic user info from
  # the AP.
  #
  # If the AuthorizationRequest object includes a redirect uri
  # then the final step will redirect the browser to that uri.
  class CallbackApi < Roda
    include RequestHelpers
    include Logging

    include OAuth2Api::Common

    def find_user_by_userdata(user_data)
      query = []
      query << { external_id: user_data[:id] }       if user_data[:id]
      if user_data[:email]
        unless user_data[:email] =~ /@/
          halt_request(400, "Invalid email address '#{user_data[:email]}'") and return
        end
        query << { email: user_data[:email] }
      end

      if query.empty?
        nil
      else
        User.or(*query).first
      end
    end

    def update_user_from_userdata(user, user_data)
      user.invite_code = nil
      user.external_id = user_data[:id]
      user.email ||= user_data[:email]
      user.name ||= user_data[:username]
      user.save ? true : false
    end

    def build_final_redirect(uri, access_token)
      redirect_uri = URI.parse(uri)
      if redirect_uri.host.nil?
        # The redirect is to the master's own /code static html, used
        # when a local browser is not an option. Code
        # is passed in url anchor section.
        redirect_uri.fragment = access_token.to_query
      else
        # The regular localhost webserver redirect.
        # The code is passed in query params.
        redirect_uri.query = access_token.to_query
      end
      redirect_uri
    end

    route do |r|
      r.get do
        params = request.params

        if params['error']
          halt_request(502, "The authorization server returned an error: #{params['error']} #{params['error_description']} #{params['error_uri']}") and return
        end

        unless params['state']
          halt_request(400, 'invalid_request') and return
        end

        state = AuthorizationRequest.find_and_invalidate(params['state'])
        unless state
          halt_request(400, 'invalid_request') and return
        end

        auth_provider = AuthProvider.instance

        unless auth_provider.valid?
          mime_halt(
            501,
            'server_error',
            'Authentication provider not configured'
          )
          return
        end

        token_data = auth_provider.get_token(params['code']) rescue nil
        if token_data.nil? || !token_data.kind_of?(Hash) || !token_data.has_key?('access_token')
          halt_request(400, 'Authentication failed') and return
        end

        user_data = auth_provider.get_userinfo(token_data['access_token']) rescue nil
        if user_data.nil? || !user_data.kind_of?(Hash)
          halt_request(400, 'Authentication failed') and return
        elsif user_data[:error]
          halt_request(400, "Authentication failed: #{user_data[:error]}") and return
        end

        user = state.user || find_user_by_userdata(user_data)
        if user.nil? || user.is_local_admin?
          halt_request(403, 'Access denied') and return
        end

        unless update_user_from_userdata(user, user_data)
          halt_request(400, "Invalid userdata #{user.errors.inspect}") and return
        end

        task = AccessTokens::Create.run(
          user: user,
          scope: 'user',
          expires_in: state.expires_in.to_i > 0 ? state.expires_in : nil,
          with_code: true
        )

        unless task.success?
          debug "Could not create internal access token: #{task.errors.message.inspect}"
          halt_request(500, 'server_error') and return
        end

        access_token = task.result
        redirect_uri = build_final_redirect(state.redirect_uri, access_token)
        request.redirect(redirect_uri.to_s)
      end
    end
  end
end
