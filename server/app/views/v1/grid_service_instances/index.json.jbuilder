json.instances @service_instances do |instance|
  json.partial! 'app/views/v1/grid_service_instances/grid_service_instance', service_instance: instance
end
