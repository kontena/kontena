json.id container.to_path
json.name container.name
json.container_id container.container_id
if container.grid
  json.grid_id container.grid.to_path
else
  json.grid_id nil
end
json.node do
  if container.host_node
    host_node = container.host_node
    json.id host_node.node_id
    json.connected host_node.connected
    json.last_seen_at host_node.last_seen_at
    json.name host_node.name
    json.labels host_node.labels
    json.public_ip host_node.public_ip
    json.private_ip host_node.private_ip
    json.node_number host_node.node_number
    json.grid do
      grid = container.grid
      json.id grid.to_path
      json.name grid.name
      json.token grid.token
      json.initial_size grid.initial_size
    end
  end
end
json.service_id container.grid_service.to_path
json.created_at container.created_at
json.updated_at container.updated_at
json.started_at container.started_at
json.finished_at container.finished_at
json.deleted_at container.deleted_at
json.status container.status
json.state container.state
json.deploy_rev container.deploy_rev
json.service_rev container.service_rev
json.image container.image
json.env container.env
json.volumes container.volumes
if container.overlay_cidr
  json.overlay_cidr container.overlay_cidr.to_s
else
  json.overlay_cidr nil
end
json.network_settings container.network_settings
if container.health_status
  json.health_status do
    json.status container.health_status
    json.updated_at container.health_status_at
  end
end
