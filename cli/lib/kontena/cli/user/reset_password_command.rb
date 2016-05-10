module Kontena::Cli::User
  class ResetPasswordCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "TOKEN", "Password reset token"

    def execute
      require 'highline/import'

      require_api_url
      password = ask("Password: ") { |q| q.echo = "*" }
      password2 = ask("Password again: ") { |q| q.echo = "*" }
      if password != password2
        abort("Passwords don't match")
      end
      params = {token: token, password: password}
      client.put('user/password_reset', params)
      puts 'Password is now changed. To login with the new password, please run: kontena login'
    end
  end
end
