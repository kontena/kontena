json.created_at volume.created_at
json.updated_at volume.updated_at
json.id volume.to_path
json.name volume.name
json.scope volume.scope
json.driver volume.driver
json.driver_opts volume.driver_opts
json.instances volume.volume_instances.map { |v|
  {
    node: v.host_node.name,
    name: v.name
  }
}

services = []

volume.grid.grid_services.each do |service|
  service.service_volumes.each do |sv|
    if sv.volume == volume
      services << service.to_path
    end
  end
end

json.services services
