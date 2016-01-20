begin
  Mongoid::QueryCache.cache {
    json.containers @containers do |container|
      json.partial! 'app/views/v1/containers/container', container: container
    end
  }
ensure
  Mongoid::QueryCache.clear_cache
end
