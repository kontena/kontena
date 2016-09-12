module OAuth2Api
  class CallbackApi < Roda
    include RequestHelpers

    def logger
      @logger ||= Server.logger
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

        token_data = AuthProvider.get_token(params['code'])

        if token_data && token_data.kind_of?(Hash) && token_data.has_key?('access_token')
          logger.debug "Retrieving user data from authentication provider"
          user_data = AuthProvider.get_userinfo(token_data['access_token'])
          logger.debug "Received user data: #{user_data.inspect}"
        else
          user_data = nil
        end

        unless user_data
          halt_request(400, 'Authentication failed') and return
        end

        if state.user
          state.user.invite_code = nil
          state.user.external_id = user_data[:id]
          state.user.email = user_data[:email]
          unless state.user.save
            halt_request(400, "Invalid userdata #{state.user.errors.inspect}") and return
          end
        end

        user = state.user || User.where(external_id: user_data[:id]).first

        unless user
          halt_request(403, 'Access denid') and return
        end

        if token_data['expires_at']
          expires_at = Time.at(token_data['expires_at'])
        elsif token_data['expires_in'].to_i > 0
          expires_at = Time.now.utc + token_data['expires_in'].to_i
        else
          expires_at = nil
        end

        # Clean up user's old access tokens
        user.access_tokens.each do |at|
          if at.expired? || at.deleted_at || (!at.internal? && at.id != external_access_token.id)
            at.destroy
          end
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
          logger.debug "Callback complete, redirecting to #{state.redirect_uri}"
          request.redirect(redirect_uri.to_s)
        else
          logger.debug "Could not create internal access token: #{task.errors.message.inspect}"
          halt_request(500, 'server_error') and return
        end
      end
    end
  end
end
