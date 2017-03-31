json.volumes @volumes do |volume|
  json.partial! 'app/views/v1/volumes/volume', volume: volume
end
