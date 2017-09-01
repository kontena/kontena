json.secrets @grid_secrets do |grid_secret|
  json.id grid_secret.to_path
  json.name grid_secret.name
  json.created_at grid_secret.created_at
  json.updated_at grid_secret.updated_at
  json.services grid_secret.services do |grid_service|
    json.id grid_service.to_path
    json.name grid_service.name
  end
end