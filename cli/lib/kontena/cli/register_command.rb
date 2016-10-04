class Kontena::Cli::RegisterCommand < Kontena::Command
  include Kontena::Cli::Common

  option "--auth-provider-url", "AUTH_PROVIDER_URL", "Auth provider URL"

  def execute
    require 'highline/import'

    auth_api_url = auth_provider_url || 'https://auth.kontena.io'
    if !auth_api_url.start_with?('http://') && !auth_api_url.start_with?('https://')
      auth_api_url = "https://#{auth_api_url}"
    end
    email = ask("Email: ")
    password = ask("Password: ") { |q| q.echo = "*" }
    password2 = ask("Password again: ") { |q| q.echo = "*" }
    if password != password2
      abort("Passwords don't match".colorize(:red))
    end
    params = {email: email, password: password}
    auth_client = Kontena::Client.new(auth_api_url)
    auth_client.post('users', params)
  end
end
