json.id grid.to_path
json.name grid.name
json.token grid.token
json.initial_size grid.initial_size
json.stats do
  json.statsd grid.stats['statsd']
end
json.trusted_subnets grid.trusted_subnets
json.node_count grid.host_nodes.count
json.service_count grid.grid_services.count
json.container_count grid.containers.count
json.user_count grid.users.count
json.subnet grid.subnet
json.supernet grid.supernet
