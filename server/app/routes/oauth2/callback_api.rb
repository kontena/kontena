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

        token_data = AuthProvider.get_token(params['code'])

        if token_data && token_data.kind_of?(Hash) && token_data.has_key?('access_token')
          debug "Retrieving user data from authentication provider"
          user_data = AuthProvider.get_userinfo(token_data['access_token'])
          debug "Received user data: #{user_data.inspect}"
        else
          user_data = nil
        end

        unless user_data
          halt_request(400, 'Authentication failed') and return
        end

        if user_data[:error]
          halt_request(400, "Authentication failed: #{user_data[:error]}") and return
        end

        # Build an array for an mongodb OR query
        query = []
        query << { external_id: user_data[:id] }       if user_data[:id]
        if user_data[:email]
          unless user_data[:email] =~ /@/
            halt_request(400, "Invalid email address '#{user_data[:email]}'") and return
          end
          query << { email: user_data[:email] }
        end

        user = state.user

        if user.nil? && !query.empty?
          user = User.or(*query).first
        end

        unless user
          halt_request(403, 'Access denid') and return
        end

        user.invite_code = nil
        user.external_id = user_data[:id]
        user.email ||= user_data[:email]
        user.name ||= user_data[:username]

        unless user.save
          halt_request(400, "Invalid userdata #{user.errors.inspect}") and return
        end

        if token_data['expires_at']
          expires_at = Time.at(token_data['expires_at'])
        elsif token_data['expires_in'].to_i > 0
          expires_at = Time.now.utc + token_data['expires_in'].to_i
        else
          expires_at = nil
        end

        task = AccessTokens::Create.run(
          user: user,
          scope: 'user',
          expires_in: state.expires_in.to_i > 0 ? state.expires_in : nil,
          with_code: true
        )

        if task.success?
          access_token = task.result
          redirect_uri = URI.parse(state.redirect_uri)
          if redirect_uri.host.nil?
            redirect_uri.fragment = access_token.to_query
          else
            redirect_uri.query = access_token.to_query
          end
          debug "Callback complete, redirecting to #{state.redirect_uri}"
          request.redirect(redirect_uri.to_s)
        else
          debug "Could not create internal access token: #{task.errors.message.inspect}"
          halt_request(500, 'server_error') and return
        end
      end
    end
  end
end
