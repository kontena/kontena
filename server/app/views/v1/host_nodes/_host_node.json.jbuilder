json.id node.to_path
json.node_id node.node_id
json.connected node.connected?
json.updated node.updated?
json.availability node.availability
json.created_at node.created_at
json.updated_at node.updated_at
json.connected_at node.connected_at
json.last_seen_at node.last_seen_at
json.disconnected_at node.disconnected_at
json.status node.status
json.has_token !node.token.nil?
json.name node.name
json.os node.os
json.engine_root_dir node.docker_root_dir
json.driver node.driver
json.network_drivers node.network_drivers.as_json(only: [:name, :version])
json.volume_drivers node.volume_drivers.as_json(only: [:name, :version])
json.kernel_version node.kernel_version
json.labels node.labels
json.mem_total node.mem_total
json.mem_limit node.mem_limit
json.cpus node.cpus
json.public_ip node.public_ip
json.private_ip node.private_ip
json.overlay_ip node.overlay_ip
json.agent_version node.agent_version
json.docker_version node.docker_version
json.peer_ips node.grid.host_nodes.ne(id: node.id).map{|n|
  if n.region == node.region
    n.private_ip
  else
    n.public_ip
  end
}.compact
json.node_number node.node_number
json.initial_member node.initial_member?
json.grid do
  grid = node.grid
  if grid
    json.id grid.to_path
    json.name grid.name
    json.initial_size grid.initial_size
    json.token grid.token
    json.stats do
      json.statsd grid.stats['statsd']
    end
    if grid.grid_logs_opts
      json.logs do
        json.forwarder grid.grid_logs_opts.forwarder
        json.opts grid.grid_logs_opts.opts
      end
    end
    json.trusted_subnets grid.trusted_subnets
    json.subnet grid.subnet
    json.supernet grid.supernet
  end
end
json.resource_usage do
  stats = node.host_node_stats.latest
  if stats
    json.memory stats.memory
    json.load stats.load
    json.filesystem stats.filesystem
    json.usage stats.usage
    json.cpu stats.cpu
  end
end
