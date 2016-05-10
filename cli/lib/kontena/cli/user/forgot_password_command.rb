module Kontena::Cli::User
  class ForgotPasswordCommand < Clamp::Command
    include Kontena::Cli::Common

    parameter "EMAIL", "Email address"

    def execute
      require_api_url

      params = {email: email}
      client.post('user/password_reset', params)
      puts 'Email with password reset instructions is sent to your email address. Please follow the instructions to change your password.'
    end
  end
end
