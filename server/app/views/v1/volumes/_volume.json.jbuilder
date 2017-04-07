json.created_at volume.created_at
json.updated_at volume.updated_at
json.id volume.to_path
json.name volume.name
json.scope volume.scope
json.driver volume.driver
json.driver_opts volume.driver_opts
json.instances volume.volume_instances.includes(:host_node).each do |v|
    json.node v.host_node.name
    json.name v.name
end
json.services volume.services.includes(:grid, :stack).each do |s|
  json.id s.to_path
end
