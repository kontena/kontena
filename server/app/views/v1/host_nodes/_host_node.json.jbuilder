json.id node.node_id
json.connected node.connected
json.created_at node.created_at
json.updated_at node.updated_at
json.last_seen_at node.last_seen_at
json.name node.name
json.os node.os
json.engine_root_dir node.docker_root_dir
json.driver node.driver
json.kernel_version node.kernel_version
json.labels node.labels
json.mem_total node.mem_total
json.mem_limit node.mem_limit
json.cpus node.cpus
json.public_ip node.public_ip
json.private_ip node.private_ip
json.peer_ips node.grid.host_nodes.ne(id: node.id).map{|n|
  if n.region == node.region
    n.private_ip
  else
    n.public_ip
  end
}.compact
json.node_number node.node_number
json.grid do
  json.partial!("app/views/v1/grids/grid", grid: node.grid) if node.grid
end
json.resource_usage do
  stats = node.host_node_stats.last
  if stats
    json.memory stats.memory
    json.load stats.load
    json.filesystem stats.filesystem
  end
end
