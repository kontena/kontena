json.id stack.to_path
json.name stack.name
json.state stack.state
json.created_at stack.created_at
json.updated_at stack.updated_at

latest_rev = stack.latest_rev || stack.stack_revisions.build
json.stack latest_rev.stack_name
json.registry latest_rev.registry
json.version latest_rev.version
json.expose latest_rev.expose
json.source latest_rev.source
json.variables latest_rev.variables
json.services stack.grid_services.to_a do |grid_service|
  json.partial! 'app/views/v1/grid_services/grid_service', grid_service: grid_service
end
