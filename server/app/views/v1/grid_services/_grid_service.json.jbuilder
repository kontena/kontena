json.id grid_service.to_path
json.created_at grid_service.created_at
json.updated_at grid_service.updated_at
json.image grid_service.image_name
json.affinity grid_service.affinity
json.name grid_service.name
json.stateful grid_service.stateful?
json.user grid_service.user
json.container_count grid_service.container_count
json.cmd grid_service.cmd
json.entrypoint grid_service.entrypoint
json.net grid_service.net
json.ports grid_service.ports
json.env grid_service.env
json.secrets grid_service.secrets.as_json(only: [:secret, :name, :type])
json.memory grid_service.memory
json.memory_swap grid_service.memory_swap
json.cpu_shares grid_service.cpu_shares
json.volumes grid_service.volumes
json.volumes_from grid_service.volumes_from
json.cap_add grid_service.cap_add
json.cap_drop grid_service.cap_drop
json.state grid_service.state
json.grid_id grid_service.grid_id.to_s
json.links grid_service.grid_service_links.map{|s| {alias: s.alias, grid_service_id: s.linked_grid_service.to_path }}
json.log_driver grid_service.log_driver
json.log_opts grid_service.log_opts
json.strategy grid_service.strategy
json.deploy_opts grid_service.deploy_opts
json.pid grid_service.pid
json.instances do
  json.total grid_service.containers.count
  json.running grid_service.containers.where('state.running' => true).count
end
json.hooks grid_service.hooks.as_json(only: [:name, :type, :cmd, :oneshot])
json.revision grid_service.revision
if grid_service.health_check
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
