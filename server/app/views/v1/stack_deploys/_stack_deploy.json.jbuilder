json.id stack_deploy.id.to_s
json.stack_id stack_deploy.stack.to_path
json.created_at stack_deploy.created_at
json.service_deploys stack_deploy.grid_service_deploys.to_a do |grid_service_deploy|
  json.partial! 'app/views/v1/grid_service_deploys/grid_service_deploy', grid_service_deploy: grid_service_deploy
end
