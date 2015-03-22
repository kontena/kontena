require_relative '../services/auth_service'

AuthService.setup do |config|
  config.api_url = ENV['AUTH_API_URL'] || 'https://auth.kontena.io'
end


