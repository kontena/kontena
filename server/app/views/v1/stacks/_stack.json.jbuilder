latest_rev = stack.latest_rev || stack.stack_revisions.build

json.id stack.to_path
json.name stack.name
json.state stack.state
json.created_at stack.created_at
json.updated_at latest_rev.created_at
json.stack latest_rev.stack_name
json.registry latest_rev.registry
json.version latest_rev.version
json.revision latest_rev.revision
json.expose latest_rev.expose
json.source latest_rev.source
json.variables latest_rev.variables
json.services stack.grid_services.to_a do |grid_service|
  json.partial! 'app/views/v1/grid_services/grid_service', grid_service: grid_service
end

if stack.has_parent?
  json.parent do
    json.id stack.parent.try(:to_path)
    json.name stack.parent_name
  end
else
  json.parent nil
end

json.children(stack.children) do |child_stack|
  json.id child_stack.to_path
  json.name child_stack.name
end
