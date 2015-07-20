json.external_registries @registries do |registry|
  json.partial! 'app/views/v1/external_registries/registry', registry: registry
end
