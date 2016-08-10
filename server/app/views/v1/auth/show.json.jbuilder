if @access_token.token_type.to_s == 'bearer'
  json.set! :token_type, @access_token.token_type

  # We only show the actual tokens for internal
  # access tokens and only upon creation, because
  # only the hashed versions are saved.
  json.set! :access_token, @access_token.token_plain
  json.set! :refresh_token, @access_token.refresh_token_plain

  json.set! :expires_in, (@access_token.expires_at - Time.now.utc).to_i
  json.user do
    json.id @access_token.user.id.to_s
    json.email @access_token.user.email
    json.name @access_token.user.name.to_s
  end
else
  # If the token isn't bearer, we will display it as an authorization code.
  json.set! :grant_type, 'authorization_code'
  json.set! :code, @access_token.code
  json.set! :redirect_uri, @access_token.redirect_uri
end
