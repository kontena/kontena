json.set! :id, access_token.id.to_s

if access_token.token_type.to_s == 'bearer'
  json.set! :token_type, access_token.token_type

  # We only show the actual tokens for internal
  # access tokens and only upon creation, because
  # only the hashed versions are saved.
  json.set! :access_token, access_token.token_plain
  json.set! :refresh_token, access_token.refresh_token_plain
  json.set! :access_token_last_four, access_token.token_last_four
  json.set! :refresh_token_last_four, access_token.refresh_token_last_four
  json.set! :expires_in, access_token.expires_in
else
  # If the token isn't bearer, we will display it as an authorization code.
  json.set! :grant_type, 'authorization_code'
  json.set! :code, access_token.code
end

json.set! :scopes, access_token.scopes.join(",")
json.set! :description, access_token.description

json.user do
  json.id access_token.user.id.to_s
  json.email access_token.user.email
  json.name access_token.user.name.to_s
end

json.server do
  json.name Server.name
end

