json.id @grid_service_deploy.id.to_s
json.created_at @grid_service_deploy.created_at
json.started_at @grid_service_deploy.started_at
json.finished_at @grid_service_deploy.finished_at
json.service_id @grid_service_deploy.grid_service.to_path
json.state @grid_service_deploy.deploy_state
json.reason @grid_service_deploy.reason
