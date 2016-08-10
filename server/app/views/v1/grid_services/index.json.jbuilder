total_counts_array = Container.counts_for_grid_services(@grid.id)
running_counts_array = Container.counts_for_grid_services(@grid.id, {:'state.running' => true})

counts = {}
total_counts_array.each do |c|
  counts[c['_id']] ||= {}
  counts[c['_id']][:total] = c['total']
end
running_counts_array.each do |c|
  counts[c['_id']] ||= {}
  counts[c['_id']][:running] = c['total']
end

json.services @grid_services do |grid_service|
  instance_counts = {
    total: counts.dig(grid_service.id, :total) || 0,
    running: counts.dig(grid_service.id, :running) || 0
  }
  json.partial! 'app/views/v1/grid_services/grid_service',
    grid_service: grid_service,
    instance_counts: instance_counts
end
