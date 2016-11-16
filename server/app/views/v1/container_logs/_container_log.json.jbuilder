json.id log.id.to_s
json.name log.name.to_s
json.container_id log.container_id.to_s
if log.grid_service
  service = log.grid_service
  json.service do
    json.id service.to_path
    json.name service.name
  end
  json.stack do
    json.id service.stack.to_path
    json.name service.stack.name
  end
  json.grid do
    json.id service.grid.to_path
    json.name service.grid.name
  end
end
json.node do
  json.name log.host_node.name if log.host_node
end
json.created_at log.created_at
json.type log.type
json.data log.data
