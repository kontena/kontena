json.id stack.to_path
json.name stack.name
json.state stack.state
json.created_at stack.created_at
json.updated_at stack.updated_at
json.version stack.version
json.services stack.grid_services.to_a do |grid_service|
  json.partial! 'app/views/v1/grid_services/grid_service', grid_service: grid_service
end
