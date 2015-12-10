json.secrets @grid_secrets do |grid_secret|
  json.id grid_secret.to_path
  json.name grid_secret.name
  json.created_at grid_secret.created_at
end