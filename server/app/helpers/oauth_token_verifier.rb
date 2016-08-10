module OAuth2TokenVerifier
  # Validate access token in request headers
  #
  def validate_access_token(*scopes)
    # These only happen when in a "soft exclude" path where
    # the headers are processed but request is not halted
    # by the token authentication middleware.
    
    unless current_user 
      halt_request(403, {error: 'Access denied'})
    end

    unless current_access_token
      halt_request(403, {error: 'Access denied'})
    end

    unless scopes.empty?
      unless current_access_token.has_scope?(*scopes)
        halt_request(403, {error: 'Access denied'})
      end
    end
  end

  def current_user
    env[TokenAuthentication::CURRENT_USER]
  end

  def current_access_token
    env[TokenAuthentication::CURRENT_TOKEN]
  end

  def current_user_admin?
    current_user && current_user.master_admin?
  end
end
