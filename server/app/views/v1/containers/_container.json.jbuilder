json.id container.to_path
json.name container.name
json.container_id container.container_id
json.grid_id container.grid_id.to_s
json.node do
  if container.host_node
    json.partial!("app/views/v1/host_nodes/host_node", node: container.host_node)
  end
end
json.service_id container.grid_service_id.to_s
json.created_at container.created_at
json.updated_at container.updated_at
json.started_at container.started_at
json.finished_at container.finished_at
json.deleted_at container.deleted_at
json.status container.status
json.state container.state
json.deploy_rev container.deploy_rev
json.image container.image
json.env container.env
json.volumes container.volumes
json.network_settings container.network_settings
