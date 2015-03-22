json.registries @registries do |registry|
  json.partial! 'app/views/v1/registries/registry', registry: registry
end
