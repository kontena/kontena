json.id authorization.to_path
json.domain authorization.domain
json.challenge authorization.challenge
json.challenge_opts authorization.challenge_opts
json.authorization_type authorization.authorization_type
if authorization.grid_service
    json.linked_service authorization.grid_service.to_path
    json.service_deploy_state authorization.service_deploy_state
end