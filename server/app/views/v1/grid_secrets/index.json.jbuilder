json.secrets @grid_secrets do |grid_secret|
  json.id grid_secret.to_path
  json.name grid_secret.name
  json.created_at grid_secret.created_at
  json.updated_at grid_secret.updated_at
  services_with_secret = @grid_services.find_all do |s|
    s.secrets.any?{|secret| secret.secret == grid_secret.name}
  end
  json.services services_with_secret.each do |grid_service|
    json.id grid_service.to_path
    json.name grid_service.name
  end
end