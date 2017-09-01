json.id authorization.to_path
json.domain authorization.domain
json.status authorization.status
json.challenge authorization.challenge
json.challenge_opts authorization.challenge_opts
json.authorization_type authorization.authorization_type
json.linked_service do
  if authorization.grid_service
    json.id authorization.grid_service.to_path
  end
end