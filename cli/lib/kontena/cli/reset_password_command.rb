class Kontena::Cli::ResetPasswordCommand < Clamp::Command
  include Kontena::Cli::Common

  parameter "TOKEN", "Password reset token"

  def execute
    require_api_url
    password = password("Password: ")
    password2 = password("Password again: ")
    if password != password2
      abort("Passwords don't match")
    end
    params = {token: token, password: password}
    client.put('user/password_reset', params)
    puts 'Password is now changed. To login with the new password, please run: kontena login'
  end
end
