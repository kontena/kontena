module Kontena::Cli::User
  class ForgotPasswordCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "EMAIL", "Email address"

    option "--auth-provider-url", "URL", "Auth provider URL", default: "https://auth.kontena.io/"

    def execute
      params = {email: email}
      auth_client = Kontena::Client.new(auth_provider_url)
      auth_client.post('user/password_reset', params)
      puts 'Email with password reset instructions is sent to your email address. Please follow the instructions to change your password.'
    end
  end
end
