json.id grid_service_deploy.id.to_s
json.created_at grid_service_deploy.created_at
json.started_at grid_service_deploy.started_at
json.finished_at grid_service_deploy.finished_at
json.service_id grid_service_deploy.grid_service.to_path
json.state grid_service_deploy.deploy_state
json.reason grid_service_deploy.reason
json.instance_count grid_service_deploy.grid_service.container_count
json.instance_deploys grid_service_deploy.grid_service_instance_deploys do |instance_deploy|
  json.instance_number instance_deploy.instance_number
  json.node instance_deploy.host_node.name
  json.state instance_deploy.deploy_state
  json.error instance_deploy.error
end
