total_counts = Container.counts_for_grid_services(@grid.id)
running_counts = Container.counts_for_grid_services(@grid.id, {:'state.running' => true})

json.services @grid_services do |grid_service|
  json.id grid_service.to_path
  json.created_at grid_service.created_at
  json.updated_at grid_service.updated_at
  json.image grid_service.image_name
  json.name grid_service.name
  json.stateful grid_service.stateful?
  json.user grid_service.user
  json.container_count grid_service.container_count
  json.cmd grid_service.cmd
  json.net grid_service.net
  json.ports grid_service.ports
  json.state grid_service.state
  json.strategy grid_service.strategy
  json.instances do
    total = total_counts.find{ |c| c['_id'] == grid_service.id } || {'total' => 0}
    json.total total['total']
    running = running_counts.find{ |c| c['_id'] == grid_service.id } || {'total' => 0}
    json.running running['total']
  end
  json.revision grid_service.revision
  json.health_status grid_service.health_status
end
