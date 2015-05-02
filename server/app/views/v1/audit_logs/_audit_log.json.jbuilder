json.time log.created_at
json.grid log.grid.name
json.grid_id log.grid_id.to_s
json.service log.grid_service_id.to_s
json.resource_type log.resource_type
json.resource_name log.resource_name
json.resource_id log.resource_id.to_s
json.event_name log.event_name
json.event_status log.event_status
json.source_ip log.source_ip
json.user_agent log.user_agent
json.user_identity do
  json.id log.user_identity['id'].to_s
  json.email log.user_identity['email']
end

