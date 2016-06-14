json.id stack.to_path
json.name stack.name
json.state stack.state
json.created_at stack.created_at
json.updated_at stack.updated_at
json.version stack.version
json.grid_services stack.grid_services.map {|s| {name: s.name, id: s.to_path}}
