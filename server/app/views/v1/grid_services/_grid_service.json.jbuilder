json.id grid_service.to_path
json.created_at grid_service.created_at
json.updated_at grid_service.updated_at
json.image grid_service.image_name
json.affinity grid_service.affinity
json.name grid_service.name
json.stateful grid_service.stateful?
json.user grid_service.user
json.instances grid_service.container_count
json.cmd grid_service.cmd
json.entrypoint grid_service.entrypoint
json.net grid_service.net
if grid_service.default_stack?
  json.dns "#{grid_service.name}.#{grid_service.grid.name}.kontena.local"
else
  json.dns "#{grid_service.name}.#{grid_service.stack.name}.#{grid_service.grid.name}.kontena.local"
end
json.ports grid_service.ports
json.env grid_service.env
json.secrets grid_service.secrets.as_json(only: [:secret, :name, :type])
json.memory grid_service.memory
json.memory_swap grid_service.memory_swap
json.shm_size grid_service.shm_size
json.cpus grid_service.cpus
json.cpu_shares grid_service.cpu_shares
json.volumes grid_service.service_volumes.map {|sv| sv.to_s}
json.volumes_from grid_service.volumes_from
json.cap_add grid_service.cap_add
json.cap_drop grid_service.cap_drop
json.state grid_service.state
json.grid do
  json.id grid_service.grid.name
end
json.stack do
  json.id grid_service.stack.to_path
  json.name grid_service.stack.name
end
json.links grid_service.grid_service_links.map { |s|
  { id: s.linked_grid_service.to_path, alias: s.alias, name: s.linked_grid_service.qualified_name } if s.linked_grid_service
}.compact
json.log_driver grid_service.log_driver
json.log_opts grid_service.log_opts
json.strategy grid_service.strategy
json.deploy_opts grid_service.deploy_opts
json.pid grid_service.pid
json.read_only grid_service.read_only
json.instance_counts do
  if defined? instance_counts
    json.total instance_counts[:total]
    json.running instance_counts[:running]
  else
    json.total grid_service.containers.count
    json.running json.running grid_service.containers.where(:'state.running' => true).count
  end
end
json.hooks grid_service.hooks.as_json(only: [:name, :type, :cmd, :oneshot])
json.revision grid_service.revision
json.stack_revision grid_service.stack_revision
if grid_service.health_check && grid_service.health_check.protocol
    json.health_check do
        json.protocol grid_service.health_check.protocol
        json.uri grid_service.health_check.uri
        json.port grid_service.health_check.port
        json.timeout grid_service.health_check.timeout
        json.initial_delay grid_service.health_check.initial_delay
        json.interval grid_service.health_check.interval
    end
    json.health_status grid_service.health_status
end
json.stop_grace_period grid_service.stop_grace_period
json.certificates grid_service.certificates.as_json(only: [:subject, :name, :type])
