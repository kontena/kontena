json.id grid_service.name
json.grid_id grid_service.grid_id.to_s
json.user grid_service.user
json.created_at grid_service.created_at
json.updated_at grid_service.updated_at
json.stateful grid_service.stateful?
json.image grid_service.image_name
json.cmd grid_service.cmd
json.entrypoint grid_service.entrypoint
json.env grid_service.env
json.ports grid_service.ports
json.container_count grid_service.container_count
json.state grid_service.state
json.links grid_service.grid_service_links.map{|s| {alias: s.alias, grid_service_id: s.linked_grid_service.id.to_s }}
