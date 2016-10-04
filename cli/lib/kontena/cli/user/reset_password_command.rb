module Kontena::Cli::User
  class ResetPasswordCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "TOKEN", "Password reset token"

    option "--auth-provider-url", "URL", "Auth provider URL", default: "https://auth.kontena.io/"

    def execute
      require 'highline/import'

      password = ask("Password: ") { |q| q.echo = "*" }
      password2 = ask("Password again: ") { |q| q.echo = "*" }
      if password != password2
        abort("Passwords don't match")
      end
      params = {token: token, password: password}
      auth_client = Kontena::Client.new(auth_provider_url)
      auth_client.put('user/password_reset', params)
      puts 'Password is now changed. To login with the new password, please run: kontena login'
    end
  end
end
