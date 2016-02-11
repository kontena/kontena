json.id node.node_id
json.connected node.connected
json.created_at node.created_at
json.updated_at node.updated_at
json.last_seen_at node.last_seen_at
json.name node.name
json.os node.os
json.driver node.driver
json.kernel_version node.kernel_version
json.labels node.labels
json.mem_total node.mem_total
json.mem_limit node.mem_limit
json.cpus node.cpus
json.public_ip node.public_ip
json.private_ip node.private_ip
peer_ips = node.grid.host_nodes.ne(id: node.id).map{|node| node.private_ip}.compact
peer_ips += grid.custom_peers
json.peer_ips peer_ips
json.node_number node.node_number
json.grid do
  grid = node.grid
  if grid
    json.id grid.to_path
    json.name grid.name
    json.token grid.token
    json.initial_size grid.initial_size
  end
end
